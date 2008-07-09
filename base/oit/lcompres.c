#include "icont.h"
#include "link.h"

#ifdef HAVE_LIBZ

#include "../h/header.h"

int file_comp(char *filename) {
  gzFile f; 
  FILE *finput;
  FILE *foutput;
  struct header *hdr;
  int n;
  char *newfname;
  char *buff;  
  char buf[200];
  char *cf;
  int c;
  
  hdr=(struct header *)malloc(sizeof(struct header));
  buff = (char *)malloc(sizeof(char)*20);
  
    
    /* use fopen() to open the target file then read the header and add "z" to the hdr->config. */
    
    if ((finput=fopen(filename,"r"))==NULL) {
      printf("Can't open the file: %s\n",filename);
      return 1;
    }
    
    newfname=(char *)malloc(strlen(filename)+3*sizeof(char));
    strcpy(newfname,filename);
    strcat(newfname,"~z");
    
    if ((foutput=fopen(newfname,"w"))==NULL) {
      printf("Can't open the file: %s\n",newfname);
      return 1;
    }

    n = strlen(IcodeDelim);
    for (;;) {
      if (fgets(buf, sizeof buf-1, finput) == NULL)
	printf("Error: Reading Error: Check if the file is executable Icon\n");
      else 
	fputs(buf, foutput);
      if (strncmp(buf, IcodeDelim, n) == 0)
	 break;
    }

    if (fread((char *)hdr, sizeof(char), sizeof(*hdr), finput) != sizeof(*hdr)) {
      fprintf(stderr, "gz compressor can't read the header, compression\n");
      return 1;
    }
    
    cf=(char *)hdr->config;
    if (strchr(cf, 'Z')==NULL)
       strcat(cf,"Z");
    else {
       /* icode already compressed, no-op */
       return 0;
       }
    
    
    /* write the modified header into a new file */
    
    fwrite((char *)hdr, sizeof(char), sizeof(*hdr), foutput);
    
    /* close the new file */
  
    fclose(foutput);
    
    /* use gzopen() to open the new file */
    
    if ((f= gzopen(newfname,"a"))==NULL) {
      printf("Error: can not open file!");
      return 1;
    }
    
    
    /*
     * read the rest of the target file and write the compressed data into
     * the new file
     */
    
    while((c=fgetc(finput))!=EOF) {
      gzputc(f,c);
      if (ferror(finput)) {
	printf("Error occurs while reading!\n");
	return 1;
      }
    }
   
    /* close both files */
    fclose(finput);
    gzclose(f);
    
  if (unlink(filename)) {
     fprintf(stderr, "can't remove old %s, compressed version left in %s\n",
	     filename, newfname);
     return 1;
     }
  if (rename(newfname, filename)) {
     fprintf(stderr, "can't rename compressed %s back to %s\n",
	     newfname, filename);
     }

  setexe(filename);

  return 0;
}

#endif					/* HAVE_LIBZ */
