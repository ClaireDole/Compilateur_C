#ifndef GENCODE_H
#define GENCODE_H

#include <stdio.h>

/* Structure d'un Quadruplet */
typedef struct {
    char *op;
    char *res;
    char *arg1;
    char *arg2;
} Quad;

extern Quad table_quads[2000];
extern int nb_quads;

/* Prototypes */
char* new_temp(void);
char* new_label(void);
void emettre_quad(char* op, char* res, char* arg1, char* arg2);
void ecrire_quads_fichier(const char* nom_fichier);

#endif
