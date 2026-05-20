#include "gencode.h"
#include <stdlib.h>
#include <string.h>

Quad table_quads[2000];
int nb_quads = 0;

static int temp_count = 0;
static int label_count = 0;

char* new_temp(void) {
    char buf[20];
    sprintf(buf, "t%d", temp_count++);
    return strdup(buf);
}

char* new_label(void) {
    char buf[20];
    sprintf(buf, "label%d", label_count++);
    return strdup(buf);
}

void emettre_quad(char* op, char* res, char* arg1, char* arg2) {
    table_quads[nb_quads].op   = op   ? strdup(op)   : NULL;
    table_quads[nb_quads].res  = res  ? strdup(res)  : NULL;
    table_quads[nb_quads].arg1 = arg1 ? strdup(arg1) : NULL;
    table_quads[nb_quads].arg2 = arg2 ? strdup(arg2) : NULL;
    nb_quads++;
}

void ecrire_quads_fichier(const char* nom_fichier) {
    FILE *f = fopen(nom_fichier, "w");
    if (!f) {
        perror("Impossible de créer le fichier de quads");
        return;
    }
    int in_func = 0; /* 1 si on est à l'intérieur d'une fonction */
    for (int i = 0; i < nb_quads; i++) {
        char* op   = table_quads[i].op;
        char* res  = table_quads[i].res;
        char* arg1 = table_quads[i].arg1;
        char* arg2 = table_quads[i].arg2;
        if (!op) continue;

        /* Suivi du contexte fonction */
        if (strcmp(op, "FUNC_START") == 0) in_func = 1;
        if (strcmp(op, "FUNC_END")   == 0) in_func = 0;

        /* --- Déclarations --- */
        if (strcmp(op, "DEC") == 0) {
            /* res=nom, arg1=type */
            fprintf(f, "%sDEC %s %s\n", in_func ? "  " : "", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "DEC_EXT") == 0) {
            fprintf(f, "extern DEC %s %s\n", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "PROTO") == 0) {
            /* res=nom_fonc, arg1=type_retour */
            fprintf(f, "PROTO %s %s\n", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "PROTO_EXT") == 0) {
            fprintf(f, "extern PROTO %s %s\n", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "PARAM_TYPE") == 0) {
            /* res=type du param dans un prototype */
            fprintf(f, "  PARAM_TYPE %s\n", res ? res : "?");

        /* --- Fonctions --- */
        } else if (strcmp(op, "FUNC_START") == 0) {
            /* res=nom_fonction */
            fprintf(f, "\nFUNC %s:\n", res ? res : "?");

        } else if (strcmp(op, "FUNC_END") == 0) {
            fprintf(f, "END_FUNC %s\n\n", res ? res : "?");

        } else if (strcmp(op, "PARAM_FETCH") == 0) {
            /* res=nom_param */
            fprintf(f, "  %s = PARAM\n", res ? res : "?");

        /* --- Labels & sauts --- */
        } else if (strcmp(op, "LABEL") == 0) {
            /* res=nom_label */
            fprintf(f, "%s:\n", res ? res : "?");

        } else if (strcmp(op, "GOTO") == 0) {
            /* arg1=label_cible */
            fprintf(f, "  GOTO %s\n", arg1 ? arg1 : "?");

        } else if (strcmp(op, "IFZ") == 0) {
            /* res=label_cible, arg1=condition */
            fprintf(f, "  IF !(%s) GOTO %s\n", arg1 ? arg1 : "?", res ? res : "?");

        /* --- Affectations --- */
        } else if (strcmp(op, "COPY") == 0) {
            /* res=dest, arg1=src  =>  dest = src */
            fprintf(f, "  %s = %s\n", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "ASSIGN") == 0) {
            /* res=dest, arg1=constante  =>  dest = cst */
            fprintf(f, "  %s = %s\n", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "ASSIGN_ADDR") == 0) {
            /* res=dest, arg1=variable  =>  dest = &variable */
            fprintf(f, "  %s = &%s\n", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "LOAD") == 0) {
            /* res=dest, arg1=ptr  =>  dest = *ptr */
            fprintf(f, "  %s = *%s\n", res ? res : "?", arg1 ? arg1 : "?");

        } else if (strcmp(op, "STORE") == 0) {
            /* res=adresse_dest, arg1=valeur  =>  *adresse = valeur */
            fprintf(f, "  *%s = %s\n", res ? res : "?", arg1 ? arg1 : "?");

        /* --- Appels de fonctions --- */
        } else if (strcmp(op, "PARAM") == 0) {
            /* arg1=valeur_argument */
            fprintf(f, "  PARAM %s\n", arg1 ? arg1 : "?");

        } else if (strcmp(op, "CALL") == 0) {
            /* res=nom_fonc, appel sans récupération de retour */
            fprintf(f, "  CALL %s\n", res ? res : "?");

        } else if (strcmp(op, "CALL_ASSIGN") == 0) {
            /* res=dest, arg1=nom_fonc  =>  dest = CALL fonc */
            fprintf(f, "  %s = CALL %s\n", res ? res : "?", arg1 ? arg1 : "?");

        /* --- Retour --- */
        } else if (strcmp(op, "RETURN") == 0) {
            fprintf(f, "  RETURN\n");

        } else if (strcmp(op, "RETURN_VAL") == 0) {
            /* arg1=valeur */
            fprintf(f, "  RETURN %s\n", arg1 ? arg1 : "?");

        /* --- Accès champ structure --- */
        } else if (strcmp(op, "GET_FIELD") == 0) {
            /* res=dest, arg1=ptr_struct, arg2=nom_champ  =>  dest = ptr->champ */
            fprintf(f, "  %s = %s->%s\n",
                    res ? res : "?",
                    arg1 ? arg1 : "?",
                    arg2 ? arg2 : "?");

        /* --- Opérations arithmétiques et logiques (format 3 adresses) --- */
        } else if (strcmp(op, "NEG") == 0) {
    /* res=dest, arg1=src  =>  dest = -src */
    fprintf(f, "  %s = -%s\n", res ? res : "?", arg1 ? arg1 : "?");
        } else {
            /* Cas général : res = arg1 OP arg2 */
            fprintf(f, "  %s = %s %s %s\n",
                    res  ? res  : "?",
                    arg1 ? arg1 : "?",
                    op,
                    arg2 ? arg2 : "?");
        }
    }
    fclose(f);
}
