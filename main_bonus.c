#include "get_next_line_bonus.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>

void print_bonus_line(char *line, const char *fd_name)
{
    if (line == NULL)
    {
        printf("[%s] : [NULL]\n", fd_name);
        return;
    }
    
    int len = 0;
    while (line[len])
        len++;
        
    if (len > 0 && line[len - 1] == '\n')
        printf("[%s] : [%.*s\\n]\n", fd_name, len - 1, line);
    else
        printf("[%s] : [%s]\n", fd_name, line);
    free(line);
}

int main(void)
{
    int fd1, fd2, fd3;

    // Open three distinct test files
    fd1 = open("text1.txt", O_RDONLY);
    fd2 = open("text2.txt", O_RDONLY);
    fd3 = open("text3.txt", O_RDONLY);

    if (fd1 < 0 || fd2 < 0 || fd3 < 0)
    {
        printf("Please create text1.txt, text2.txt, and text3.txt before running.\n");
        return (1);
    }

    printf("--- Start Interleaved Multi-FD Bonus Test ---\n");

    // Interleave reads to check static safety limits
    print_bonus_line(get_next_line(fd1), "FD 1 - Line 1");
    print_bonus_line(get_next_line(fd2), "FD 2 - Line 1");
    print_bonus_line(get_next_line(fd3), "FD 3 - Line 1");
    
    print_bonus_line(get_next_line(fd1), "FD 1 - Line 2");
    print_bonus_line(get_next_line(fd2), "FD 2 - Line 2");
    print_bonus_line(get_next_line(fd3), "FD 3 - Line 2");

    print_bonus_line(get_next_line(fd1), "FD 1 - EOF Check");
    print_bonus_line(get_next_line(fd2), "FD 2 - EOF Check");
    print_bonus_line(get_next_line(fd3), "FD 3 - EOF Check");

    close(fd1);
    close(fd2);
    close(fd3);
    return (0);
}

/* # 1. Create temporary files to verify the interleaved output
echo -e "Hello from file 1\nSecond line of file 1" > text1.txt
echo -e "Bonjour du fichier 2\nDeuxieme ligne du fichier 2" > text2.txt
echo -e "Hola desde archivo 3\nSegunda linea del archivo 3" > text3.txt

# 2. Compile with bonus files
cc -Wall -Wextra -Werror -D BUFFER_SIZE=4 main_bonus.c get_next_line_bonus.c get_next_line_utils_bonus.c

# 3. Run the binary (Optionally wrap it with valgrind)
valgrind --leak-check=full ./a.out

# 4. Clean temporary files
rm -f text1.txt text2.txt text3.txt
 */