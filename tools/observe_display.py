#!/usr/bin/env python3
"""Finite, read-only display observation. Never changes settings or drives SPI."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo


class IdentityMismatch(RuntimeError):
    pass


def read_sample(origin, device_id, read=None):
    def fetch(name):
        with urllib.request.urlopen(origin + '/api/local/' + name, timeout=6) as response:
            return response.read()
    read = read or fetch
    health = json.loads(read('health'))
    if health.get('device_id') != device_id:
        raise IdentityMismatch('Device identity changed; observation stopped')
    result = {'at': datetime.datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
              'health': health}
    if health.get('display_busy'):
        result['frame_skipped'] = 'display_busy'
    else:
        try:
            frame = read('base')
            if len(frame) != 48000:
                raise ValueError('Unexpected frame length')
            result['frame_sha256'] = hashlib.sha256(frame).hexdigest()
        except urllib.error.HTTPError as error:
            if error.code != 423:
                raise
            result['frame_skipped'] = 'became_busy'
    return result


def summarize(samples):
    good = [s for s in samples if 'health' in s]
    hashes = {s['frame_sha256'] for s in good if 'frame_sha256' in s}
    uptimes = [s['health']['uptime_seconds'] for s in good
               if 'uptime_seconds' in s['health']]
    result = {'samples': len(samples), 'read_errors': len(samples) - len(good),
              'different_frame_hashes': len(hashes), 'optical_result': 'not_observed',
              'restart_observed': any(b < a for a, b in zip(uptimes, uptimes[1:]))}
    # Do not subtract reset counters or interpret old firmware's absent fields as zero.
    for key in ('display_refresh_commands', 'display_refresh_completed',
                'display_differential_windows'):
        if good and all(key in s['health'] for s in good):
            values = [s['health'][key] for s in good]
            if not result['restart_observed'] and all(b >= a for a, b in zip(values, values[1:])):
                result[key + '_delta'] = values[-1] - values[0]
            else:
                result[key + '_delta'] = None
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--device-id', required=True)
    parser.add_argument('--seconds', type=int, default=120)
    parser.add_argument('--interval', type=int, default=10)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    url = urllib.parse.urlsplit(args.url)
    if url.scheme not in ('http', 'https') or not url.hostname or url.username or url.password or url.query or url.fragment or url.path not in ('', '/'):
        parser.error('--url must be a device origin without credentials, path or query')
    if not 1 <= args.interval <= 60 or not 0 <= args.seconds <= 86400:
        parser.error('interval must be 1..60; seconds must be 0..86400')
    samples = []
    deadline = time.monotonic() + args.seconds
    args.output.parent.mkdir(parents=True, exist_ok=True)
    while True:
        try:
            sample = read_sample(args.url.rstrip('/'), args.device_id)
        except IdentityMismatch:
            raise
        except (OSError, ValueError) as error:
            sample = {'read_error': type(error).__name__}
        samples.append(sample)
        document = {'summary': summarize(samples), 'samples': samples}
        temporary = args.output.with_suffix(args.output.suffix + '.tmp')
        temporary.write_text(json.dumps(document, indent=2), encoding='utf-8')
        temporary.replace(args.output)
        health = sample.get('health', {})
        print(json.dumps({'sample': len(samples), 'busy': health.get('display_busy'),
                          'baseline': health.get('baseline_ready'),
                          'refresh_commands': health.get('display_refresh_commands'),
                          'read_error': sample.get('read_error')}, ensure_ascii=False), flush=True)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(args.interval, remaining))
    print(json.dumps(document['summary']), flush=True)


if __name__ == '__main__':
    main()
