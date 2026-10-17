#pragma once
// GDEY075Z08 corrected-register waveform protocol:
// previous image = 0x13; current image = 0x10 (GxEPD2 writeImageToPrevious/Current).
inline void differentialWindow(unsigned int x,unsigned int y,unsigned int w,unsigned int h,void(*command)(unsigned char),void(*data)(unsigned char)){
 command(0x91);command(0x90);
 const unsigned int coords[]={x,x+w-1,y,y+h-1};
 for(unsigned int c:coords){data(c>>8);data(c&255);}data(0x00);
}
inline void differentialPlane(unsigned char reg,const unsigned char* image,unsigned int x,unsigned int y,unsigned int w,unsigned int h,void(*command)(unsigned char),void(*data)(unsigned char)){
 command(reg);
 for(unsigned int row=y;row<y+h;row++)for(unsigned int col=x/8;col<(x+w)/8;col++)data(image[row*100+col]);
}
inline void differentialImages(const unsigned char* oldImage,const unsigned char* newImage,unsigned int x,unsigned int y,unsigned int w,unsigned int h,void(*command)(unsigned char),void(*data)(unsigned char)){
 differentialWindow(x,y,w,h,command,data);
 differentialPlane(0x13,oldImage,x,y,w,h,command,data);
 differentialPlane(0x10,newImage,x,y,w,h,command,data);
}
