"""Build a project-local, bounded fork of the pinned Arduino WebServer.

Never changes the shared framework installation. Upstream files retain LGPL
notices. A changed framework fails closed until this patch is reviewed again.
Can also be imported by host tests without PlatformIO/SCons.
"""
from pathlib import Path
import hashlib
import re
import shutil

HASHES = {
    "Parsing.cpp": "122de5397729899ac8600d545f7ed4b8a02298351a4f1b0fa5c7fa73f87a14d0",
    "WebServer.h": "7770ef659d332dee92947cf7d98097874c39583a9113fd66735ca329459c8e8b",
}

def once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError("WebServer patch context changed: " + old[:70])
    return text.replace(old, new)

def patched_header(text):
    text = once(text, '#include "Uri.h"', '#include "Uri.h"\n#include "MojianRequestGuard.h"')
    return once(text, '  bool _parseRequest(WiFiClient& client);',
        '  MojianRequestReader<WiFiClient> _boundedReader;\n'
        '  bool _parseRequestBounded(WiFiClient& client);\n'
        '  bool _parseRequest(WiFiClient& client);')

def patched_parser(text):
    # The original allocator grows using untrusted available() sizes. The local
    # variant allocates the validated declared length and reads through the guard.
    start=text.index('static char* readBytesWithTimeout(')
    end=text.index('bool WebServer::_parseRequest(', start)
    text=text[:start]+'''static char* readBytesWithTimeout(MojianRequestReader<WiFiClient>& reader, size_t maxLength, size_t& dataLength, int) {
  dataLength=0;
  if(maxLength==0)return nullptr;
  if(maxLength>MojianRequestReader<WiFiClient>::FIELD_LIMIT){reader.reject();return nullptr;}
  char* bytes=(char*)malloc(maxLength+1);
  if(!bytes){reader.reject();return nullptr;}
  dataLength=reader.readBytes(bytes,maxLength);bytes[dataLength]=0;return bytes;
}
bool WebServer::_parseRequest(WiFiClient& client) {
  _boundedReader.begin(client);
  bool ok=_parseRequestBounded(client)&&!_boundedReader.failed();
  if(!ok){
    client.stop();
    if(_currentUpload && _currentUpload->status!=UPLOAD_FILE_ABORTED)
      _parseFormUploadAborted();
  }
  return ok;
}
'''+text[end:]
    # Keep the wrapper and rename only the original implementation.
    marker='bool WebServer::_parseRequest(WiFiClient& client) {'
    last=text.rindex(marker)
    text=text[:last]+text[last:].replace(marker,'bool WebServer::_parseRequestBounded(WiFiClient& client) {',1)
    text=text.replace('client.readStringUntil(', '_boundedReader.readStringUntil(')
    # Every line read, including multipart metadata, must leave its loop on EOF
    # or timeout rather than interpreting an empty timed-out line as more data.
    text=re.sub(r'(^[^\n]*_boundedReader\.readStringUntil\([^\n]*;)$',
        r'\1\n      if(_boundedReader.failed())return false;', text, flags=re.M)
    text=once(text, '    if (!isForm && _currentHandler && _currentHandler->canRaw(_currentUri)){',
        '''    if(_clientContentLength>MojianRequestReader<WiFiClient>::BODY_LIMIT ||
       (!isForm && _clientContentLength>MojianRequestReader<WiFiClient>::FIELD_LIMIT) ||
       (isForm && (boundaryStr.length()==0 || boundaryStr.length()>128)))return false;
    _boundedReader.beginBody();
    if (!isForm && _currentHandler && _currentHandler->canRaw(_currentUri)){''')
    text=once(text, 'client.readBytes(_currentRaw->buf, HTTP_RAW_BUFLEN)',
        '_boundedReader.readBytes((char*)_currentRaw->buf, std::min((size_t)HTTP_RAW_BUFLEN, (size_t)(_clientContentLength-_currentRaw->totalSize)))')
    text=once(text, 'readBytesWithTimeout(client,', 'readBytesWithTimeout(_boundedReader,')
    start=text.index('int WebServer::_uploadReadByte(')
    end=text.index('bool WebServer::_parseForm(',start)
    text=text[:start]+'''int WebServer::_uploadReadByte(WiFiClient&) {
  return _boundedReader.readByte();
}

'''+text[end:]
    text=once(text, '              argValue += line;',
        '''              if(argValue.length()+line.length()>MojianRequestReader<WiFiClient>::FIELD_LIMIT)return false;
              argValue += line;''')
    text=once(text, '  (void) len;',
        '''  (void) len;
  size_t fieldValueBytes=0,fieldNameBytes=0;''')
    text=once(text, '            RequestArgument& arg = _postArgs[_postArgsLen++];',
        '''            // Bound the whole retained form, not just each value. The
            // argument-array copy briefly holds both sets of String buffers.
            if(argValue.length()>MojianRequestReader<WiFiClient>::FIELD_LIMIT-fieldValueBytes ||
               argName.length()>MojianRequestReader<WiFiClient>::HEADER_LINE_LIMIT-fieldNameBytes)return false;
            fieldValueBytes+=argValue.length();fieldNameBytes+=argName.length();
            RequestArgument& arg = _postArgs[_postArgsLen++];''')
    return '#include <algorithm>\n'+text

def prepare(framework, destination, project):
    upstream=Path(framework)/'libraries/WebServer'
    for name, expected in HASHES.items():
        actual=hashlib.sha256((upstream/'src'/name).read_bytes()).hexdigest()
        if actual!=expected:
            raise RuntimeError('Unsupported WebServer '+name+' SHA-256: '+actual)
    destination=Path(destination)
    for source in (upstream/'src').rglob('*'):
        if source.is_file():
            target=destination/'src'/source.relative_to(upstream/'src')
            target.parent.mkdir(parents=True,exist_ok=True)
            if source.name=='Parsing.cpp': content=patched_parser(source.read_text()).encode()
            elif source.name=='WebServer.h': content=patched_header(source.read_text()).encode()
            else: content=source.read_bytes()
            if not target.exists() or target.read_bytes()!=content: target.write_bytes(content)
    shutil.copyfile(upstream/'library.properties',destination/'library.properties')
    guard=Path(project)/'src/request_guard.h'
    target=destination/'src/MojianRequestGuard.h'
    if not target.exists() or target.read_bytes()!=guard.read_bytes(): shutil.copyfile(guard,target)

if 'Import' in globals():
    Import('env')
    project=Path(env.subst('$PROJECT_DIR'))
    framework=env.PioPlatform().get_package_dir('framework-arduinoespressif32')
    prepare(framework, project/'.pio/webserver-libs/WebServer', project)
