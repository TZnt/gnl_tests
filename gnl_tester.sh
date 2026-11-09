#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}        VALIDEUR ABSOLU GET_NEXT_LINE (42)       ${NC}"
echo -e "${BLUE}==================================================${NC}"

if ! command -v valgrind &> /dev/null; then
    echo -e "${RED}❌ Valgrind est nécessaire mais non installé.${NC}"
    exit 1
fi

# --- ÉTAPE 1 : Génération dynamique du fichier C de test ---
cat << 'EOF' > main_mandatory_auto.c
#include "get_next_line.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

int main(int ac, char **av) {
    // 1. Mode test de robustesse des arguments invalides
    if (ac > 1 && strcmp(av[1], "check_invalid_args") == 0) {
        char *err_fd = get_next_line(-1);
        if (err_fd != NULL) { free(err_fd); return (42); } // Code 42: FD invalide non géré
        
        #if defined(BUFFER_SIZE) && BUFFER_SIZE <= 0
        char *err_buf = get_next_line(0);
        if (err_buf != NULL) { free(err_buf); return (43); } // Code 43: BUFFER_SIZE <= 0 non géré
        #endif
        
        return (0);
    }
    
    // 2. Mode lecture et affichage sur stdout (pour comparaison avec diff)
    int fd = 0;
    if (ac > 1 && strcmp(av[1], "stdin") != 0) {
        fd = open(av[1], O_RDONLY);
        if (fd < 0) return (1);
    }
    
    char *line;
    while ((line = get_next_line(fd)) != NULL) {
        printf("%s", line);
        free(line);
    }
    if (fd > 0) close(fd);
    return (0);
}
EOF

cat << 'EOF' > main_bonus_auto.c
#include "get_next_line_bonus.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

int main(void) {
    int fd1 = open("b1.txt", O_RDONLY);
    int fd2 = open("b2.txt", O_RDONLY);
    int fd3 = open("b3.txt", O_RDONLY);
    char *l;
    
    l = get_next_line(fd1); if (l) { printf("[FD1]: %s", l); free(l); }
    l = get_next_line(fd2); if (l) { printf("[FD2]: %s", l); free(l); }
    l = get_next_line(fd3); if (l) { printf("[FD3]: %s", l); free(l); }
    l = get_next_line(fd1); if (l) { printf("[FD1]: %s", l); free(l); }
    l = get_next_line(fd2); if (l) { printf("[FD2]: %s", l); free(l); }
    l = get_next_line(fd3); if (l) { printf("[FD3]: %s", l); free(l); }
    
    close(fd1); close(fd2); close(fd3);
    return (0);
}
EOF

# --- ÉTAPE 2 : Génération des fichiers de référence ---
echo -e "a\nab\nabc\nx\ny\nz" > f_short.txt
echo -e "\n\n\na\n\nb" > f_empty.txt
python3 -c "print('A'*2050 + '\n' + 'B'*3000)" > f_long.txt
echo -e "FD1-L1\nFD1-L2" > b1.txt
echo -e "FD2-L1" > b2.txt
echo -e "FD3-L1\nFD3-L2" > b3.txt

# --- ÉTAPE 3 : Moteur de vérification (Comportement + Mémoire) ---
assert_test() {
    local cmd="$1"
    local reference_file="$2"
    local test_label="$3"
    
    # 1. Vérification Mémoire (Valgrind écrit dans valgrind_report.txt, gnl écrit dans gnl_output.txt)
    valgrind --leak-check=full --show-leak-kinds=all $cmd > gnl_output.txt 2> valgrind_report.txt
    local exit_status=$?
    
    local leaks=$(grep -E "definitely lost:|indirectly lost:|possibly lost:" valgrind_report.txt | grep -v "0 bytes in 0 blocks")
    local mem_errors=$(grep -E "ERROR SUMMARY:" valgrind_report.txt | grep -v "0 errors from 0 contexts")
    
    # 2. Vérification Comportementale (Diff entre la sortie GNL et le fichier d'origine)
    local diff_errors=""
    if [ -n "$reference_file" ]; then
        diff -a gnl_output.txt "$reference_file" > diff_report.txt
        if [ $? -ne 0 ]; then
            diff_errors="Erreur: Le texte lu ne correspond pas au fichier d'origine."
        fi
        rm -f diff_report.txt
    fi

    # 3. Analyse des statuts d'erreurs spécifiques
    if [ $exit_status -eq 42 ]; then
        echo -e "  ↳ $test_label : ${RED}[ FAILURE ] (La fonction n'a pas renvoyé NULL avec un FD de -1)${NC}"
    elif [ $exit_status -eq 43 ]; then
        echo -e "  ↳ $test_label : ${RED}[ FAILURE ] (La fonction n'a pas renvoyé NULL avec un BUFFER_SIZE <= 0)${NC}"
    elif [ -n "$diff_errors" ]; then
        echo -e "  ↳ $test_label : ${RED}[ FAILURE ] (Comportement incorrect / Ligne ou \\n manquant)${NC}"
    elif [ -n "$leaks" ] || [ -n "$mem_errors" ]; then
        echo -e "  ↳ $test_label : ${RED}[ FAILURE ] (Fuite ou erreur mémoire détectée par Valgrind)${NC}"
        grep -E "lost:|ERROR SUMMARY:" valgrind_report.txt
    else
        echo -e "  ↳ $test_label : ${GREEN}[ SUCCESS ]${NC}"
    fi
    rm -f valgrind_report.txt gnl_output.txt
}

run_mandatory_batch() {
    local b_size=$1
    echo -e "${YELLOW}▶ Analyse Mandatory (BUFFER_SIZE = $b_size)${NC}"
    
    cc -Wall -Wextra -Werror -D BUFFER_SIZE=$b_size main_mandatory_auto.c get_next_line.c get_next_line_utils.c -o gnl_test
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Échec critique de compilation.${NC}"
        exit 1
    fi

    assert_test "./gnl_test check_invalid_args" "" "Vérification des arguments invalides (FD / BUFFER_SIZE)"
    assert_test "./gnl_test f_short.txt" "f_short.txt" "Lignes courtes et multiples"
    assert_test "./gnl_test f_empty.txt" "f_empty.txt" "Lignes vides consécutives"
    assert_test "./gnl_test f_long.txt" "f_long.txt" "Lignes très longues (2k+)"
}

# --- ÉTAPE 4 : Lancement des vagues de tests ---
run_mandatory_batch 1
run_mandatory_batch 42
run_mandatory_batch 10000

# Cas particulier BUFFER_SIZE invalide (0 et -42)
echo -e "${YELLOW}▶ Analyse avec BUFFER_SIZE invalide (<= 0)${NC}"
cc -Wall -Wextra -Werror -D BUFFER_SIZE=0 main_mandatory_auto.c get_next_line.c get_next_line_utils.c -o gnl_test 2>/dev/null
if [ $? -eq 0 ]; then
    assert_test "./gnl_test check_invalid_args" "" "Vérification BUFFER_SIZE = 0"
else
    echo -e "  ↳ Vérification BUFFER_SIZE = 0 : ${GREEN}[ SUCCESS ] (La compilation a bloqué la valeur, sécurité OK)${NC}"
fi

cc -Wall -Wextra -Werror -D BUFFER_SIZE=-42 main_mandatory_auto.c get_next_line.c get_next_line_utils.c -o gnl_test 2>/dev/null
if [ $? -eq 0 ]; then
    assert_test "./gnl_test check_invalid_args" "" "Vérification BUFFER_SIZE = -42"
else
    echo -e "  ↳ Vérification BUFFER_SIZE = -42 : ${GREEN}[ SUCCESS ] (La compilation a bloqué la valeur, sécurité OK)${NC}"
fi

# Test Stdin
echo -e "${YELLOW}▶ Analyse Entrée Standard (stdin)${NC}"
cc -Wall -Wextra -Werror -D BUFFER_SIZE=42 main_mandatory_auto.c get_next_line.c get_next_line_utils.c -o gnl_test
echo -e "Ligne stdin 1\nLigne stdin 2" > expected_stdin.txt
echo -e "Ligne stdin 1\nLigne stdin 2" | valgrind --leak-check=full ./gnl_test stdin > gnl_output.txt 2> valgrind_report.txt
diff -a gnl_output.txt expected_stdin.txt &>/dev/null
if [ $? -eq 0 ] && grep -E "ERROR SUMMARY:" valgrind_report.txt | grep -q "0 errors from 0 contexts" && grep -q "All heap blocks were freed" valgrind_report.txt; then
    echo -e "  ↳ Lecture via Stdin : ${GREEN}[ SUCCESS ]${NC}"
else
    echo -e "  ↳ Lecture via Stdin : ${RED}[ FAILURE ]${NC}"
fi
rm -f valgrind_report.txt gnl_output.txt expected_stdin.txt

# --- ÉTAPE 5 : Section Bonus ---
echo ""
read -p "Souhaitez-vous valider la partie BONUS ? (y/n) : " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    echo -e "${YELLOW}▶ Analyse des structures Bonus (Lecture alternée multi-FD)${NC}"
    cc -Wall -Wextra -Werror -D BUFFER_SIZE=4 main_bonus_auto.c get_next_line_bonus.c get_next_line_utils_bonus.c -o gnl_bonus &>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "[FD1]: FD1-L1\n[FD2]: FD2-L1\n[FD3]: FD3-L1\n[FD1]: FD1-L2\n[FD3]: FD3-L2" > expected_bonus.txt
        assert_test "./gnl_bonus" "expected_bonus.txt" "Multiples File Descriptors en simultané"
        rm -f expected_bonus.txt
    else
        echo -e "  ↳ Fichiers Bonus : ${RED}[ FAILURE ] (Erreur compilation / Fichiers manquants)${NC}"
    fi
fi

# Nettoyage complet
rm -f gnl_test gnl_bonus main_mandatory_auto.c main_bonus_auto.c f_short.txt f_empty.txt f_long.txt b1.txt b2.txt b3.txt
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}               FIN DES VÉRIFICATIONS              ${NC}"
echo -e "${BLUE}==================================================${NC}"
