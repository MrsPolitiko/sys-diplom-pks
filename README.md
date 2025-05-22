# sys-diplom-pks
## Дипломный проект учащейся Политико Ксения


Проект содержит все необходимые файлы в текущей директории, в том числе и ключи доступа (вырезаны через gitignore) 
Основной файл это main.tf он разворачивает инфраструктуру в облаке Яндекс.
Ансибл запускается из машины с проектом следующей командой: ansible-playbook -i ./hosts.ini file_name.yml 


Разворачивание проекта осуществляется запуском файла script/deploy.sh


 Для пересоздания проекта используй ключ clear: script/deploy.sh clear



#### Особенность ansible:

    В один день ansible.builtin.command: | (именно с |) у тебя будет работать, в другой посылает лесом. \
    Используй ansible.builtin.shell: |



#### Особенность создания БД через ansible

    По умолчанию PostgreSQL разрешает доступ только через Unix-сокет с peer-аутентификацией (всякие там login_host тут не работают) поэтому без должной настройки использование встроенных postgres команд не получится. Самый простой вариант оказался выполнить bash команды.



#### Особенонсть разворачивания zabbix под ubuntu 22.04

    Дефолтные конфиги с nginx не работают, из коробки оно не заведется. 
    Обязательно!
        1. Удалить default-сайт /etc/nginx/sites-enabled/default

        2. Добавить ссылку на наш конфиг, чтобы nginx подхватывал его:
             sudo ln -s /etc/zabbix/nginx.conf /etc/nginx/sites-enabled/zabbix.conf

        3. Раскомментировать в /etc/zabbix/nginx.conf:
            - listen 8080; и заменить listen 80;
            - server_name example.com; и заменить server_name IP_ZABBIX;

        4. Закоментировать строку в /etc/zabbix/nginx.conf в "location ~ [^/]\.php(/|$) {}":
            # fastcgi_param   PATH_TRANSLATED /usr/share/zabbix$fastcgi_script_name;

        5. Добавить эту строчку: 
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        6. Заменили в файле /etc/zabbix/nginx.conf:
            fastcgi_pass    unix:/var/run/php/zabbix.sock;
            на 
            fastcgi_pass    unix:/var/run/php/php8.1-fpm.sock;
           Оказывается! Внезапно для разрабов zabbix что в Ubuntu 22.04 используется версионный сокет php8.1, а не общий zabbix.sock
           Проверить какой используется: sudo grep -r "listen =" /etc/php/8.1/fpm/
           Или какой создан: ls -la /var/run/php/php*.sock

        7. Я разочарована в ansible. Нет, оно работает, но, всегда есть НО. В общем, на мой взгляд лучше не использовать 
           встроенные модули, а тупо делать всё через shell. Больше нервов сохранишь и времени, ну или писать их самой. 
           Оказалось проще записать целыйы конфиг nginx чем использовать regexp из-под модуля ansible.


 Запуск playbook происходит из bastion, обращение к машинам из playbook осуществляеся по FQDN прописанным в hosts bastion.
  
  