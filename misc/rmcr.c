#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv);


int main(int argc, char **argv)
{
   int c;
   FILE *f_in;

   if (argc == 1) {
       f_in = stdin;
   } else {
       if ((f_in = fopen(argv[1], "r")) == NULL) {
           fprintf(stderr, "Couldn't open %s\n", argv[1]);
           exit(1);
       }
   }

   while ((c = getc(f_in)) != EOF) {
       if (c != 13)
           putchar(c);
   }

   fclose(f_in);
   exit(0);
}
