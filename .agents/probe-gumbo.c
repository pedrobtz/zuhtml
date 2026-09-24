/* Probe harness behind the measurements in roadmap.md ("Design review 2026-09-24").
 * Not part of the package. Build against a pristine Gumbo 0.14.0 checkout:
 *   clang -O2 -std=c99 -w -DNDEBUG -I<gumbo>/src <gumbo>/src/*.c probe-gumbo.c -o probe
 * Run:  ./probe <mode> <n> [destroy]
 * Modes: deep flat aaa foster attrs dupattrs saw sawp text entities.
 * It counts every Gumbo allocation through the allocator hooks and reports
 * parse time, peak live bytes, bytes-per-input-byte and allocation count.
 */
#include "gumbo.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static size_t live=0, peak=0, count=0;
static void* al(void* u, size_t n){ (void)u; char* p = malloc(n+16); if(!p) abort(); *(size_t*)p=n; live+=n; count++; if(live>peak)peak=live; return p+16; }
static void de(void* u, void* p){ (void)u; if(!p) return; char* q=(char*)p-16; live-=*(size_t*)q; free(q);}
static char* rep(const char* unit, size_t n, size_t* len){ size_t ul=strlen(unit); char* b=malloc(n*ul+1); for(size_t i=0;i<n;i++) memcpy(b+i*ul,unit,ul); b[n*ul]=0; *len=n*ul; return b; }
int main(int argc, char** argv){
  const char* mode = argv[1]; size_t n = strtoull(argv[2],0,10); size_t len; char* buf;
  if(!strcmp(mode,"deep")) buf=rep("<div>",n,&len);
  else if(!strcmp(mode,"flat")) buf=rep("<p class=\"c1 c2\" id=\"x\">Hello <b>world</b> and more text here.</p>\n",n,&len);
  else if(!strcmp(mode,"aaa")) buf=rep("<a><b>",n,&len);
  else if(!strcmp(mode,"foster")) { char* body=rep("<div>x</div>",n,&len); buf=malloc(len+32); strcpy(buf,"<table>"); memcpy(buf+7,body,len); buf[7+len]=0; len+=7; free(body);} 
  else if(!strcmp(mode,"attrs")) { size_t l; char* a=rep(" a=1",n,&l); buf=malloc(l+16); strcpy(buf,"<p"); memcpy(buf+2,a,l); strcpy(buf+2+l,">"); len=l+3; free(a);} 
  else if(!strcmp(mode,"dupattrs")) { size_t l; char* a=rep(" a=1 b=2 c=3",n,&l); buf=malloc(l+16); strcpy(buf,"<p"); memcpy(buf+2,a,l); strcpy(buf+2+l,">"); len=l+3; free(a);} 
  else if(!strcmp(mode,"saw")) { size_t l1,l2; char* o=rep("<div>",500,&l1); char* c=rep("</div>",500,&l2); char* tooth=malloc(l1+l2+1); memcpy(tooth,o,l1); memcpy(tooth+l1,c,l2); tooth[l1+l2]=0; buf=rep(tooth,n,&len); }
  else if(!strcmp(mode,"sawp")) { size_t l1,l2; char* o=rep("<p><a><b>",170,&l1); char* c=rep("</b></a></p>",170,&l2); char* tooth=malloc(l1+l2+1); memcpy(tooth,o,l1); memcpy(tooth+l1,c,l2); tooth[l1+l2]=0; buf=rep(tooth,n,&len); }
  else if(!strcmp(mode,"text")) buf=rep("abcdefghij",n,&len);
  else if(!strcmp(mode,"entities")) buf=rep("&amp;&notanentity;&#x41;",n,&len);
  else return 2;
  GumboOptions opt = kGumboDefaultOptions; opt.allocator=al; opt.deallocator=de; opt.max_errors=100;
  clock_t t0=clock();
  GumboOutput* out = gumbo_parse_with_options(&opt, buf, len);
  clock_t t1=clock();
  printf("mode=%-9s n=%-8zu input=%9zu B parse=%7.3fs peak_alloc=%10zu B ratio=%5.1fx allocs=%9zu errors=%u\n", mode,n,len,(double)(t1-t0)/CLOCKS_PER_SEC, peak,(double)peak/len,count,out->errors.length);
  fflush(stdout);
  if(argc>3 && !strcmp(argv[3],"destroy")){ t0=clock(); gumbo_destroy_output(&opt,out); t1=clock(); printf("  destroy ok in %.3fs, live=%zu\n",(double)(t1-t0)/CLOCKS_PER_SEC,live);}
  return 0;
}
