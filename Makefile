CC      = gcc
CFLAGS  = -Wall -pedantic -g -I. -O0 -Wextra
LDFLAGS =
LEX     = flex
YACC    = bison

# Fichiers du compilateur frontend
YACC_FE   = structfe_no_actions.y
LEX_FE    = lexeur_fe.lex
SRCS_FE   = structfe.tab.c lex.yy.c tablesymb.c gestion_tables.c \
            main.c erreur.c affichage.c gencode.c
OBJS_FE   = structfe.tab.o lex.yy.o tablesymb.o gestion_tables.o \
            main.o erreur.o affichage.o gencode.o
TARGET_FE = compilateur

# Fichiers du parseur backend
YACC_BE   = structbe.y
LEX_BE    = lexeur_be.lex
SRCS_BE   = backend.tab.c lex_be.yy.c
OBJS_BE   = backend.tab.o lex_be.yy.o
TARGET_BE = parseur_backend

# Répertoire de tests
TEST_DIR  = tests

# Couleurs console
GREEN  = \033[1;32m
RED    = \033[1;31m
YELLOW = \033[1;33m
BLUE   = \033[1;34m
CYAN   = \033[1;36m
NC     = \033[0m

.PHONY: all clean distclean run test run-file verify help init

# Cible par défaut : construire les deux exécutables
all: $(TARGET_FE) $(TARGET_BE)

# FRONTEND : compilateur STRUCIT-frontend -> code 3 adresses

structfe.tab.c structfe.tab.h: $(YACC_FE)
	@echo "$(YELLOW)[BISON FE]$(NC) Generation du parseur frontend..."
	$(YACC) -d -v -o structfe.tab.c $<
	@cp structfe.tab.h y.tab.h

lex.yy.c: $(LEX_FE) structfe.tab.h
	@echo "$(YELLOW)[FLEX FE]$(NC) Generation du lexeur frontend..."
	$(LEX) -o lex.yy.c $<

$(TARGET_FE): $(OBJS_FE)
	@echo "$(YELLOW)[LD]$(NC) Liaison du compilateur : $(TARGET_FE)"
	$(CC) $(CFLAGS) $(OBJS_FE) -o $(TARGET_FE) $(LDFLAGS)
	@echo "$(GREEN)[OK] Compilateur frontend pret : $(TARGET_FE)$(NC)"

# BACKEND : parseur de vérification STRUCIT-backend

backend.tab.c backend.tab.h: $(YACC_BE)
	@echo "$(YELLOW)[BISON BE]$(NC) Generation du parseur backend..."
	$(YACC) -d -v -p backend -o backend.tab.c $<

lex_be.yy.c: $(LEX_BE) backend.tab.h
	@echo "$(YELLOW)[FLEX BE]$(NC) Generation du lexeur backend..."
	$(LEX) --prefix=backend -o lex_be.yy.c $<

$(TARGET_BE): $(OBJS_BE)
	@echo "$(YELLOW)[LD]$(NC) Liaison du parseur : $(TARGET_BE)"
	$(CC) $(CFLAGS) $(OBJS_BE) -o $(TARGET_BE) $(LDFLAGS)
	@echo "$(GREEN)[OK] Parseur backend pret : $(TARGET_BE)$(NC)"

# Règle générique de compilation
%.o: %.c
	@echo "$(YELLOW)[CC]$(NC) Compilation de $<"
	$(CC) $(CFLAGS) -c $< -o $@

# INIT : crée le dossier tests avec un fichier minimal
init:
	@echo "$(YELLOW)[INIT]$(NC) Creation du dossier de tests..."
	@mkdir -p $(TEST_DIR)
	@if [ ! -f "$(TEST_DIR)/accept.c" ]; then \
		echo "int main(void) { int a; a = 42; return a; }" > $(TEST_DIR)/accept.c; \
		echo "$(GREEN)[OK] Fichier exemple cree dans $(TEST_DIR)/accept.c$(NC)"; \
	fi

# RUN : compile UN fichier et vérifie le backend généré
# Usage : make run              -> utilise tests/accept.c
#         make run FILE=mon.c   -> utilise mon.c
run: $(TARGET_FE) $(TARGET_BE)
	$(eval F := $(if $(FILE),$(FILE),$(TEST_DIR)/accept.c))
	@if [ ! -f "$(F)" ]; then \
		echo "$(RED)[ERROR]$(NC) Fichier '$(F)' introuvable."; \
		exit 1; \
	fi
	@echo ""
	@echo "$(CYAN) Compilation de : $(F)$(NC)"
	@./$(TARGET_FE) "$(F)"; \
	BASE=$$(echo "$(F)" | sed 's/\.[^.]*$$//'); \
	BE="$${BASE}_be"; \
	if [ -f "$$BE" ]; then \
		echo "$(GREEN)[OK]$(NC) Code genere : $$BE"; \
		echo ""; \
		echo "$(BLUE) Verification backend : $$BE $(NC)"; \
		if ./$(TARGET_BE) "$$BE"; then \
			echo "$(GREEN)[VALID]$(NC) $$BE est syntaxiquement correct."; \
		else \
			echo "$(RED)[INVALID]$(NC) $$BE contient des erreurs backend."; \
		fi; \
	else \
		echo "$(RED)[ERROR]$(NC) Aucun fichier backend genere pour $(F)."; \
	fi

# RUN-FILE : alias de run avec FILE obligatoire
# Usage : make run-file FILE=tests/mon_test.c
run-file: $(TARGET_FE) $(TARGET_BE)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)[ERROR]$(NC) Syntaxe : make run-file FILE=chemin/fichier.c"; \
		exit 1; \
	fi
	@$(MAKE) run FILE=$(FILE)

# TEST : compile TOUS les .c de tests/ et vérifie chaque _be
test: $(TARGET_FE) $(TARGET_BE)
	@echo ""
	@echo "$(CYAN) COMPILATION ET VERIFICATION : dossier $(TEST_DIR)/$(NC)"
	@mkdir -p $(TEST_DIR)
	@ok=0; fail=0; \
	for f in $(TEST_DIR)/*.c; do \
		[ -f "$$f" ] || continue; \
		echo ""; \
		echo "$(YELLOW) Traitement : $$f$(NC)"; \
		./$(TARGET_FE) "$$f"; \
		fe_exit=$$?; \
		base=$$(echo "$$f" | sed 's/\.[^.]*$$//'); \
		be="$${base}_be"; \
		if [ $$fe_exit -eq 0 ] && [ -f "$$be" ]; then \
			echo "$(GREEN)  [FE OK]$(NC) Code 3 adresses -> $$be"; \
			if ./$(TARGET_BE) "$$be" > /dev/null 2>&1; then \
				echo "$(GREEN)  [BE OK]$(NC) $$be est valide."; \
				ok=$$((ok+1)); \
			else \
				echo "$(RED)  [BE FAIL]$(NC) $$be contient des erreurs backend :"; \
				./$(TARGET_BE) "$$be"; \
				fail=$$((fail+1)); \
			fi; \
		else \
			echo "$(RED)  [FE FAIL]$(NC) Echec de compilation de $$f"; \
			fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; \
	echo "$(GREEN)  Succes : $$ok$(NC)   $(RED)Echecs : $$fail$(NC)"

# VERIFY : vérifie un fichier _be existant sans recompiler le source
# Usage : make verify BE=tests/accept_be
verify: $(TARGET_BE)
	@if [ -z "$(BE)" ]; then \
		echo "$(RED)[ERROR]$(NC) Syntaxe : make verify BE=chemin/fichier_be"; \
		exit 1; \
	fi
	@if [ ! -f "$(BE)" ]; then \
		echo "$(RED)[ERROR]$(NC) Fichier '$(BE)' introuvable."; \
		exit 1; \
	fi
	@echo "$(BLUE) Verification backend : $(BE) $(NC)"
	@if ./$(TARGET_BE) "$(BE)"; then \
		echo "$(GREEN)[VALID]$(NC) $(BE) est syntaxiquement correct."; \
	else \
		echo "$(RED)[INVALID]$(NC) $(BE) contient des erreurs."; \
		exit 1; \
	fi

# CLEAN / DISTCLEAN
clean:
	@echo "$(YELLOW)[CLEAN]$(NC) Suppression des objets et fichiers generes..."
	@rm -f $(OBJS_FE) $(OBJS_BE)
	@rm -f $(TARGET_FE) $(TARGET_BE)
	@rm -f structfe.tab.c structfe.tab.h lex.yy.c y.tab.h structfe.output
	@rm -f backend.tab.c backend.tab.h lex_be.yy.c backend.output
	@echo "$(YELLOW)[CLEAN]$(NC) Suppression des fichiers generes (*_be)..."
	@rm -f $(TEST_DIR)/*_be
	@echo "$(GREEN)[OK] Nettoyage effectue.$(NC)"

distclean: clean
	@echo "$(YELLOW)[DISTCLEAN]$(NC) Suppression du dossier $(TEST_DIR)/..."
	@rm -rf $(TEST_DIR)
	@echo "$(GREEN)[OK] Projet entierement nettoye.$(NC)"

# HELP
help:
	@echo ""
	@echo "$(YELLOW)Construction :$(NC)"
	@echo "  make              Compile le frontend ET le parseur backend"
	@echo "  make init         Cree tests/ avec un fichier minimal"
	@echo ""
	@echo "$(YELLOW)Execution :$(NC)"
	@echo "  make run                    Compile tests/accept.c et verifie le _be"
	@echo "  make run FILE=mon.c         Compile mon.c et verifie le _be genere"
	@echo "  make run-file FILE=mon.c    Alias de run FILE="
	@echo "  make test                   Compile tous les .c de tests/ et verifie chaque _be"
	@echo "  make verify BE=tests/f_be   Verifie un fichier _be existant"
	@echo ""
	@echo "$(YELLOW)Nettoyage :$(NC)"
	@echo "  make clean        Supprime objets, executables et fichiers *_be"
	@echo "  make distclean    Supprime tout + le dossier tests/"
	@echo ""
