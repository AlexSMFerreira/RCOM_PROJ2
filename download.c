/*
 * FEUP - RCOM Lab 2 - FTP Download Application
 * Baseado em clientTCP.c e getip.c fornecidos.
 * Implementa RFC959 (FTP) e RFC1738 (URL).
 */

#include <stdio.h>
#include <stddef.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <unistd.h>
#include <netdb.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>

#define FTP_PORT 21
#define MAX_LENGTH 1024

// Estrutura para guardar os dados do URL 
struct URL {
    char user[MAX_LENGTH];
    char password[MAX_LENGTH];
    char host[MAX_LENGTH];
    char path[MAX_LENGTH];
    char filename[MAX_LENGTH];
};

/**
 * Função para ler a resposta do socket de controlo.
 * Lê até encontrar uma nova linha.
 * Retorna o código de estado FTP (ex: 220, 331, 230).
 */
int read_ftp_response(int sockfd, char *str) {
    FILE *fp = fdopen(dup(sockfd), "r");
    int code = -1, temp = 0;
    size_t len = 0;
    char *line = NULL;

    // O FTP pode enviar várias linhas. A última começa com "CODE " (espaço)
    // As intermédias começam com "CODE-" (hífen) 
    while (getline(&line, &len, fp) != -1) {
        printf("S: %s", line); // Imprimir o que o servidor diz (Debug/Log)

        if (strlen(line) < 4) continue; // ignorar linhas curtas
        if (!isdigit((unsigned char) line[0]) || !isdigit((unsigned char) line[1]) || !isdigit((unsigned char) line[2])) continue;

        sscanf(line, "%d", &temp);
        if (line[3] == ' ') {
            code = temp;
            if (str != NULL && line != NULL) {
                snprintf(str, MAX_LENGTH, "%s", line);
            }
            break;
        }
    }
    
    free(line);
    fclose(fp);
    return code;
}

/**
 * Função para enviar comandos para o socket de controlo
 */
int send_ftp_command(int sockfd, char *str) {
    printf("C: %s", str); // Imprimir o que estamos a enviar (Debug/Log)
    size_t bytes = write(sockfd, str, strlen(str));
    if (bytes <= 0) {
        perror("write()");
        return -1;
    }
    return 0;
}

//  Cria e conecta um socket a um IP e Porta específicos.

int connect_socket(char *ip, int port) {
    int sockfd;
    struct sockaddr_in server_addr;

    /*server address handling*/
    bzero((char *) &server_addr, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = inet_addr(ip);
    server_addr.sin_port = htons(port);

    /*open a TCP socket*/
    if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("socket()");
        return -1;
    }

    /*connect to the server*/
    if (connect(sockfd, (struct sockaddr *) &server_addr, sizeof(server_addr)) < 0) {
        perror("connect()");
        return -1;
    }

    return sockfd;
}


//  Resolve o nome de host para IP.
int get_ip(char *hostname, char *ip_buffer) {
    struct hostent *h;

    if ((h = gethostbyname(hostname)) == NULL) {
        herror("gethostbyname()");
        return -1;
    }

    strcpy(ip_buffer, inet_ntoa(*((struct in_addr *) h->h_addr)));
    printf("Host name  : %s\n", h->h_name);
    printf("IP Address : %s\n", ip_buffer);
    return 0;
}

// Parser do URL: ftp://[user:pass@]host/path

int parse_url(char *input, struct URL *url) {
    char *p = strstr(input, "ftp://");
    if (!p) return -1;
    p += 6; // Avançar "ftp://"

    char *at_sign = strchr(p, '@');
    char *slash = strchr(p, '/');

    if (at_sign) {
        // Tem credenciais
        char creds[MAX_LENGTH];
        strncpy(creds, p, at_sign - p);
        creds[at_sign - p] = '\0';
        
        char *colon = strchr(creds, ':');
        if (colon) {
            strncpy(url->user, creds, colon - creds);
            url->user[colon - creds] = '\0';
            strcpy(url->password, colon + 1);
        } else {
            strcpy(url->user, creds);
            strcpy(url->password, ""); // Sem password ou pedir depois
        }
        p = at_sign + 1;
    } else {
        // Default anónimo
        strcpy(url->user, "anonymous");
        strcpy(url->password, "anonymous@");
    }

    // Host e Path
    if (slash) {
        strncpy(url->host, p, slash - p);
        url->host[slash - p] = '\0';
        strcpy(url->path, slash + 1);
    } else {
        strcpy(url->host, p);
        strcpy(url->path, "");
    }

    // Filename (última parte do path)
    char *last_slash = strrchr(url->path, '/');
    if (last_slash) strcpy(url->filename, last_slash + 1);
    else strcpy(url->filename, url->path);

    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s ftp://[user:pass@]host/path\n", argv[0]);
        exit(-1);
    }

    struct URL url;
    if (parse_url(argv[1], &url) < 0) {
        fprintf(stderr, "Erro no formato do URL.\n");
        exit(-1);
    }

    if (url.filename[0] == '\0') {
        fprintf(stderr, "Caminho/ficheiro em falta no URL.\n");
        exit(-1);
    }

    printf("User: %s | Pass: %s | Host: %s | Path: %s | File: %s\n", 
           url.user, url.password, url.host, url.path, url.filename);

    // Obter IP (DNS)
    char ip[20];
    if (get_ip(url.host, ip) < 0) exit(-1);

    // Conectar Socket de Controlo (Porta 21) 
    int sockfd_ctrl = connect_socket(ip, FTP_PORT);
    if (sockfd_ctrl < 0) exit(-1);

    // Ler Boas-vindas (220) 
    if (read_ftp_response(sockfd_ctrl, NULL) != 220) {
        fprintf(stderr, "Erro na conexão ao servidor.\n");
        close(sockfd_ctrl);
        exit(-1);
    }

    // Enviar USER 
    char cmd[MAX_LENGTH];
    sprintf(cmd, "USER %s\r\n", url.user);
    send_ftp_command(sockfd_ctrl, cmd);
    int code = read_ftp_response(sockfd_ctrl, NULL);
    if (code != 331 && code != 230) exit(-1);

    // Enviar PASS 
    if (code == 331) {
        sprintf(cmd, "PASS %s\r\n", url.password);
        send_ftp_command(sockfd_ctrl, cmd);
        if (read_ftp_response(sockfd_ctrl, NULL) != 230) {
            fprintf(stderr, "Erro no login.\n");
            exit(-1);
        }
    }

    // Mudar para modo Binário (TYPE I)
    sprintf(cmd, "TYPE I\r\n");
    send_ftp_command(sockfd_ctrl, cmd);
    if (read_ftp_response(sockfd_ctrl, NULL) != 200) {
        fprintf(stderr, "Erro ao mudar para modo binário.\n");
    }

    // Entrar em modo Passivo (PASV)
    sprintf(cmd, "PASV\r\n");
    send_ftp_command(sockfd_ctrl, cmd);
    char pasv_response[MAX_LENGTH];
    if (read_ftp_response(sockfd_ctrl, pasv_response) != 227) {
        fprintf(stderr, "Erro ao entrar em modo passivo.\n");
        exit(-1);
    }

    // Calcular Porta de Dados 
    int ip1, ip2, ip3, ip4, p1, p2;
    // Parse da resposta: "Entering Passive Mode (193,137,29,15,198,138)."
    char *start_ip = strchr(pasv_response, '(');
    if (!start_ip || sscanf(start_ip, "(%d,%d,%d,%d,%d,%d)", &ip1, &ip2, &ip3, &ip4, &p1, &p2) != 6) {
        fprintf(stderr, "Não foi possível interpretar a resposta PASV.\n");
        exit(-1);
    }
    int data_port = p1 * 256 + p2;
    char pasv_ip[32];
    snprintf(pasv_ip, sizeof(pasv_ip), "%d.%d.%d.%d", ip1, ip2, ip3, ip4);
    printf("Modo Passivo: IP %s Porta %d\n", pasv_ip, data_port);

    // Conectar Socket de Dados 
    int sockfd_data = connect_socket(pasv_ip, data_port);
    if (sockfd_data < 0) exit(-1);

    // Pedir Ficheiro (RETR)    
    sprintf(cmd, "RETR %s\r\n", url.path);
    send_ftp_command(sockfd_ctrl, cmd);
    int retr_code = read_ftp_response(sockfd_ctrl, NULL);
    if (retr_code != 150 && retr_code != 125) {
        fprintf(stderr, "Erro ao iniciar transferência (código %d).\n", retr_code);
        exit(-1);
    }

    // Transferir Dados (Download Loop) 
    FILE *file = fopen(url.filename, "wb");
    if (!file) {
        perror("fopen()");
        exit(-1);
    }

    char buf[MAX_LENGTH];
    int bytes_read;
    while ((bytes_read = read(sockfd_data, buf, MAX_LENGTH)) > 0) {
        fwrite(buf, 1, bytes_read, file);
    }
    fclose(file);
    close(sockfd_data); // Fechar socket de dados

    // Ler resposta final (226 Transfer Complete) 
    if (read_ftp_response(sockfd_ctrl, NULL) != 226) {
        fprintf(stderr, "Transferência incompleta ou erro.\n");
    } else {
        printf("Download completo: %s guardado.\n", url.filename);
    }

    // Fechar conexão de controlo (QUIT) 
    sprintf(cmd, "QUIT\r\n");
    send_ftp_command(sockfd_ctrl, cmd);
    read_ftp_response(sockfd_ctrl, NULL);
    close(sockfd_ctrl);

    return 0;
}