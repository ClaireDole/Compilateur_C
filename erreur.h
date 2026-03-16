#ifndef ERREUR_H
#define ERREUR_H
enum erreurs {
    LEXICALE,
    SYNTAXE,
    SEMANTIQUE,
};
void afficher_erreur(void);
void erreur(enum erreurs type, int ligne, const char* explication, char* s);
void afficher_warning(void);
void warning(enum erreurs type, int ligne,const char* explication, char* s);
#endif