#include "get_next_line.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

void print_line(char *line, int line_num)
{
    if (line == NULL)
    {
        printf("Line %d: [NULL] (End of File or Error)\n", line_num);
        return;
    }
    
    // Check if the line ends with a newline character
    int len = 0;
    while (line[len])
        len++;
        
    if (len > 0 && line[len - 1] == '\n')
    {
        // Print the line without the literal raw jump, substituting with "\n" visually
        printf("Line %d: [%.*s\\n]\n", line_num, len - 1, line);
    }
    else
    {
        printf("Line %d: [%s] (Warning: Missing \\n at the end)\n", line_num, line);
    }
}

int main(int ac, char **av)
{
    int		fd;
    char	*line;
    int		i;

    // Test Error Handling directly
    printf("--- Test: Invalid FD (-1) ---\n");
    line = get_next_line(-1);
    if (line == NULL)
        printf("Result: NULL (Success - Error handled properly)\n");
    else
    {
        printf("Result: [%s] (FAIL - Should return NULL on bad FD)\n", line);
        free(line);
    }

    // Determine the source (stdin or file)
    if (ac > 1 && strcmp(av[1], "stdin") == 0)
    {
        printf("\n--- Test: Standard Input (stdin) ---\n");
        fd = 0;
    }
    else if (ac > 1)
    {
        printf("\n--- Test: Reading File [%s] ---\n", av[1]);
        fd = open(av[1], O_RDONLY);
        if (fd < 0)
        {
            perror("Error opening file");
            return (1);
        }
    }
    else
    {
        printf("\nUsage: ./a.out <filename> OR ./a.out stdin\n");
        return (1);
    }

    // Read loop
    i = 1;
    while ((line = get_next_line(fd)) != NULL)
    {
        print_line(line, i++);
        free(line);
    }
    
    // Final check: must return NULL at EOF
    print_line(line, i);
    
    if (fd > 0)
        close(fd);
    return (0);
}
/* # Compile with a custom BUFFER_SIZE
cc -Wall -Wextra -Werror -D BUFFER_SIZE=42 main_mandatory.c get_next_line.c get_next_line_utils.c

# Run it on a text file
./a.out path_to_file.txt

# Run it interactively with standard input
./a.out stdin
 */