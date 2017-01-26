void 
nmz_delete_backslashes(char *str)
{
    char *pos = str;

    while (*str) {
        if (*str == '\\' && *(str + 1) == '\\') {
            *pos = *str;
            pos++;
            str++;
            str++;
        } else if (*str == '\\') {
            str++;
        } else {
            *pos = *str;
            pos++;
            str++;
        }
    }
    *pos = '\0';
}

int 
nmz_strsuffixcasecmp(char *str1, char *str2)
{
    int leng1, leng2;

    leng1 = strlen(str1);
    leng2 = strlen(str2);

    if (leng1 > leng2) {
	return strcasecmp(str1 + leng1 - leng2, str2);
    } else {					     
	return strcasecmp(str2 + leng2 - leng1, str1);
    }
}


