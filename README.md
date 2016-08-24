
# Containers orchestration (parte 2)

En la [primera parte](http://devadictos.com/orquestando-docker-containers-parte-i/) de este post construimos los Dockerfile para cada uno de los elementos que forman parte de nuestra aplicación. Ahora, en este post, los vamos a echar a andar, o dicho de otro modo los vamos a "orquestar". Para tal efecto vamos utilizaremos [docker-compose](https://docs.docker.com/compose/), (en adelante `DC` para abreviar) que viene incluida en el 'kit Docker'.

`DC` es una herramienta que basada en un archivo de configuración `.yml`, le dirá a nuestro Docker host, qué hacer con cada container y cuales son las relaciones entre ellos. Además, podremos definir volúmenes, configuraciones de red así como la interacción con otros nodos(docker machines por ejemplo) de un mismo o de distintos clusters.

Nuestro archivo `docker-compose.yml` será tal que [así]()

Cabe resaltar que vamos a utilizar las funcionalidades presentes en la versión 2 de `DC`, por lo tanto hemos añadido en la parte superior `version: '2'`.


## Container para BD
Analizando cada uno de nuestros "servicios", como son llamados los containers en nuestro archivo ym, podemos darnos cuenta que la estructura es muy sencilla. Para comenzar la etiqueta `build` le indica a `DC` dónde se encuentra nuestro fichero Dockerfile en base al cual se construirá la imagen para cada container.

Además podemos definir un nombre para nuestros containers con `container_name` y con `ports` definimos la lista de puertos que el container expone al mundo exterior.

Nuestro nodo para la base de datos quedaría como:

```
devadictos-db:
  build:
    context: ./
    dockerfile: Dockerfile.db
  container_name: 'devadictos-db'
  ports:
    - "3306:3306"
```

## Container para la aplicación
El container en donde estará nuestra aplicación, además de lo anterior añadirá el atributo `links`. Este atribuo indica a cada servicio con qué otros containers se relaciona el container actual. Además podemos establecer un alias para cada una de las relaciones. Debo recordar que el ámbito de este alias será el propio container y no más que él.

```
links:
  - devadictos-db:db
```

En este caso le decimos a `DC` que nuestro container de aplicación estará relacionado con el container de base de datos, Y, dentro de nuestro container de aplicación utilizaremos el alias `db` para hacer referencia al de base de datos. La apariencia final será algo así:

```
devadictos-app:
  build:
    context: ./
    dockerfile: Dockerfile.app
  container_name: 'devadictos-app'
  ports:
    - "9000:9000"
  links:
    - devadictos-db:db
```

## Container para Nginx
Nuestro último container es el que se encargará de gestionar las peticiones HTTP que lleguen a nuestro docker host. Utilizaremos como ya hemos dicho antes, Nginx.

De la misma forma, indicaremos la ubicación del Dockerfile, añadiendo también los containers con los que está relacionado. En este caso, sólamente con nuestra aplicación

```
devadictos-nginx:
  build:
    context: ./
    dockerfile: Dockerfile.nginx
  container_name: 'devadictos-server'
  ports:
    - "80:80"
  links:
    - devadictos-app:devadictos
```

Ya tenemos todos los elementos listos, sin embargo hace falta un pequeño detalle. Cuando una petición HTTP llegue a nuestro servidor, Nginx que escucha los puertos 80 y 443, intentará responder. De momento como no hemos definido, cuando alguien intente acceder a nuestra aplicación devolverá la página por defecto de Nginx.

Para solucionarlo, crearemos un Virtual Host que redirigirá todas las peticiones a nuestra aplicación.

```
server {
  listen       80;
  server_name  symfony-app.devadictos.com;
	access_log   /var/log/nginx/access-symfony-app.devadictos.com.log;
	error_log    /var/log/nginx/error-symfony-app.devadictos.com.log error;
  root         /usr/share/nginx/html/devadictos-app/web;

  location / {
    # try to serve file directly, fallback to app.php
    index app.php;
    try_files $uri /app.php$is_args$args;
  }

  # DEV
  location ~ ^/(app_dev|config)\.php(/|$) {
    fastcgi_pass devadictos:9000;
    fastcgi_split_path_info ^(.+\.php)(/.*)$;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_read_timeout 120;
  }

  # PROD
  location ~ ^/app\.php(/|$) {
    fastcgi_pass devadictos:9000;
    fastcgi_split_path_info ^(.+\.php)(/.*)$;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_read_timeout 120;
  }
}
```

Entre otras cosas este archivo define dónde está ubicada el código (`root /usr/share/nginx/html/devadictos-app/web;`), qué tiene que hacer con los archivos PHP (`fastcgi_pass devadictos:9000;`) y dónde estarán los ficheros de logs (`access_log /var/log/nginx/access-symfony-app.devadictos.com.log;` y `error_log /var/log/nginx/error-symfony-app.devadictos.com.log error;`).

Si os dais cuenta, he definido que nuestro virtual host escuche las entradas provenientes de `server_name symfony-app.devadictos.com;`. Para poder probar en local tenemos dos opciones. 1. Modificar la entrada e introducir `localhost` o similiar (ó) 2. Añadir a nuestro archivo `/etc/hosts` una entrada para que todo lo que vaya a `symfony-app.devadictos.com` se redirija a nuestro servidor local: `192.168.99.100  symfony-app.devadictos.com
`

## Up and running
Parece ser que tenemos todo listo para echar a andar nuestros containers orquestados. Pues bien, allá vamos

```
$ docker-compose up -d
```

Creará las imagenes necesarias para los containers y seguidamente los iniciará. Al final de la ejecución deberíamos ver algo parecido a:

```
Creating devadictos-db
Creating devadictos-app
Creating devadictos-server
Attaching to devadictos-db, devadictos-app, devadictos-server
```

Echamos un ojo a los containers creados:

```
CONTAINER ID        IMAGE                            COMMAND                  CREATED             STATUS                         PORTS                         NAMES
63d2452930b7        dockercompose_devadictos-nginx   "nginx -g 'daemon off"   About an hour ago   Up About an hour               0.0.0.0:80->80/tcp, 443/tcp   devadictos-server
90a61a957f78        dockercompose_devadictos-app     "php5-fpm -F"            About an hour ago   Up About an hour               0.0.0.0:9000->9000/tcp        devadictos-app
d1daaecbb466        dockercompose_devadictos-db      "docker-entrypoint.sh"   About an hour ago   Up About an hour                                             devadictos-db
```

Si todo ha ido bien deberíamos ser capaces de ver la página de bienvenida de Symfony. Accediendo en nuetro navegador a `http://symfony-app.devadictos.com` o a la dirección que hayamos definido en nuestro Virtua Host.

## Troubleshoting
Durante la puesta en marcha de este ejemplo me encontré con una serie de problemas que he tenido a bien mencionaros por si os sirven de ayuda en un futuro

* **tty:true:**
  Cuando añadí el atributo `tty:true` a un nodo en `docker-compose.yml`, después de unos momentos obtenía el siguiente mensaje de error

  ```
  ERROR: An HTTP request took too long to complete.
  Retry with --verbose to obtain debug information.
  If you encounter this issue regularly because of slow network conditions,
  consider setting COMPOSE_HTTP_TIMEOUT to a higher value (current value: 60).
  ```

  *La solución fue quitar tal atributo*

* **Container terminado con Error 0:**
  Al crear en container para Nginx, éste no se quedaba ejecutándose sino más bien terminaba y mostraba un mensaje de eror
  ```
  dockercompose_devadictos-nginx_1 exited with code 0
  ```

  *La solución fue modificar la sentencia `CMD` del docker file*
  ```
  CMD ["nginx"]
  CMD ["nginx", "-g", "daemon off;"]
  ```

* **PHP Connection refused:**
  Cuando el virtual host redirigía el stream al container PHP obtenía este error
  ```
  connect() failed (111: Connection refused)
  ```

  Encontré la solución en [stackoverflow](http://stackoverflow.com/questions/21524373/nginx-connect-failed-111-connection-refused-while-connecting-to-upstream) y fue crear un archivo de configuración para decirle a PHP que acepte conexiones desde cualquier origen. Dado que el encargado de gestionar la seguridad es nuestro Docker host no he querido definir restricciones. Sin embargo una buena práctica de seguridad hacer lo propio.

  ```
  listen = 0.0.0.0:9000
  ```
