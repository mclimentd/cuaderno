# Sintaxis y normas de desarrollo de Cuaderno

## 1. Qué es Cuaderno

Cuaderno es una aplicación construida sobre WordPress.

Las vistas de la aplicación se almacenan como páginas reales de WordPress:

- `post_type = page`
- el contenido de la vista está almacenado en `wp_posts.post_content`
- las páginas pueden contener Gutenberg/UAGB, HTML, CSS y JavaScript
- además utilizan un lenguaje dinámico propio de Cuaderno basado en expresiones `[[...]]`

El repositorio Git contiene copias versionadas de esas páginas para permitir su desarrollo con VS Code, Codex y Git.

Los archivos del repositorio NO son páginas HTML independientes: representan el `post_content` de páginas WordPress reales.

---

# 2. Estructura de una página

Cada página exportada se almacena de esta forma:

```text
pages/
└── nombre_pagina/
    ├── page.json
    └── content.html
```

## page.json

Contiene los metadatos necesarios para identificar el post WordPress.

Ejemplo:

```json
{
  "ID": 478,
  "post_title": "alumno_plan_trabajo",
  "post_status": "publish",
  "post_name": "alumno_plan_trabajo",
  "post_type": "page"
}
```

El `ID`, `post_name` y `post_type` no deben modificarse salvo petición expresa.

## content.html

Representa el contenido de:

```text
wp_posts.post_content
```

Puede contener simultáneamente:

1. serialización Gutenberg/UAGB
2. HTML
3. CSS
4. JavaScript
5. lenguaje dinámico propio de Cuaderno

---

# 3. Regla fundamental

Toda expresión delimitada por:

```text
[[ ... ]]
```

pertenece al motor de Cuaderno.

Debe conservarse literalmente salvo que la tarea solicite expresamente modificar la lógica de Cuaderno.

Codex NO debe:

- eliminar expresiones `[[...]]`
- renombrarlas
- reformatearlas
- convertirlas a PHP
- convertirlas a JavaScript
- sustituirlas por variables HTML
- escapar los corchetes
- interpretar estas expresiones como errores HTML

---

# 4. Vistas

Cuaderno puede delimitar una vista mediante:

```text
[[VIEW tarjetas]]

...

[[ENDVIEW]]
```

`VIEW` selecciona o define una vista dinámica.

No modificar el nombre de la vista salvo petición expresa.

---

# 5. Registro padre

La sintaxis:

```text
[[PARENT campo]]
```

permite acceder a información del registro padre o relacionado.

Ejemplos:

```text
[[PARENT id_alumno]]

[[PARENT id_solicitud_cliente.titulo]]

[[PARENT id_solicitud_cliente.id_proyecto.nombre]]
```

Las relaciones pueden encadenarse mediante puntos.

Estas expresiones pueden aparecer:

- como texto
- dentro de atributos HTML
- en `src`
- en `alt`
- dentro de URLs
- dentro de atributos `data-*`

No deben alterarse salvo petición expresa.

---

# 6. Registro actual

Dentro de una vista o iteración pueden utilizarse campos:

```text
[[campo]]
```

o relaciones:

```text
[[relacion.campo]]
```

Ejemplos:

```text
[[id_plan_trabajo.titulo]]

[[id_plan_trabajo.orden]]

[[id_estado.nombre]]

[[porcentaje_completado]]

[[fecha_inicio_real]]
```

---

# 7. Iteraciones

Cuaderno utiliza:

```text
[[FOREACH]]

...

[[ENDFOREACH]]
```

El contenido comprendido entre ambas instrucciones se genera para cada registro de la colección correspondiente.

No mover, eliminar ni duplicar `FOREACH` o `ENDFOREACH` sin analizar previamente la estructura de datos.

---

# 8. Condiciones

Cuaderno permite condiciones:

```text
[[IF condicion]]

...

[[ENDIF]]
```

Ejemplo:

```text
[[IF id_estado.nombre='Validada']]is-verde[[ENDIF]]

[[IF id_estado.nombre='En curso']]is-azul[[ENDIF]]

[[IF id_estado.nombre='Pendiente']]is-gris[[ENDIF]]

[[IF id_estado.nombre='Atrasada']]is-rojo[[ENDIF]]
```

Estas condiciones pueden aparecer dentro de:

- clases CSS
- atributos HTML
- estilos inline
- texto
- URLs

No deben transformarse en condiciones JavaScript o PHP.

---

# 9. OPTIONS y otras instrucciones

Pueden existir otras instrucciones del motor como:

```text
[[OPTIONS ...]]
```

o cualquier otra construcción:

```text
[[INSTRUCCION ...]]
```

Aunque no esté documentada en este archivo, debe considerarse sintaxis propia de Cuaderno.

Regla:

> Cualquier expresión `[[...]]` desconocida debe conservarse literalmente.

Codex debe analizarla antes de proponer modificaciones.

---

# 10. WordPress y Gutenberg

Los comentarios:

```html
<!-- wp:... -->
```

y:

```html
<!-- /wp:... -->
```

pertenecen a la serialización de bloques Gutenberg.

Ejemplos:

```html
<!-- wp:html -->
<!-- /wp:html -->

<!-- wp:uagb/container {...} -->
<!-- /wp:uagb/container -->
```

No deben eliminarse ni reorganizarse arbitrariamente.

Los objetos JSON incluidos en comentarios Gutenberg/UAGB forman parte de la configuración de los bloques.

---

# 11. HTML

El HTML contenido en `content.html` puede modificarse cuando la tarea lo requiera.

Sin embargo, antes de modificar estructura HTML debe comprobarse si existen dependencias con:

- JavaScript
- CSS
- atributos `data-*`
- clases `js-*`
- IDs
- expresiones `[[...]]`

No cambiar selectores utilizados por JavaScript sin modificar y validar también su lógica.

---

# 12. CSS

Las modificaciones exclusivamente visuales deben realizarse preferentemente mediante CSS.

Para una tarea visual:

- conservar HTML si no es necesario modificarlo
- conservar JavaScript
- conservar atributos `data-*`
- conservar expresiones `[[...]]`
- conservar enlaces
- conservar clases utilizadas por JavaScript

Antes de modificar CSS existente, comprobar posibles reglas heredadas del tema WordPress.

---

# 13. JavaScript

No modificar JavaScript en tareas exclusivamente visuales.

Antes de modificar JavaScript identificar:

- elementos seleccionados mediante `querySelector`
- clases `js-*`
- IDs
- atributos `data-*`
- enlaces construidos dinámicamente
- valores procedentes de expresiones `[[...]]`

Las comprobaciones JavaScript destinadas a detectar valores todavía no sustituidos por Cuaderno deben conservarse.

---

# 14. Atributos data-*

Los atributos:

```html
data-*
```

pueden utilizarse para transferir información desde Cuaderno al JavaScript de la página.

No eliminarlos, renombrarlos ni cambiar su contenido sin comprobar el JavaScript que los consume.

---

# 15. Clases js-*

Las clases con nombres similares a:

```text
js-*
```

deben considerarse selectores funcionales y no meramente visuales.

Ejemplos:

```text
js-sc-code
js-sc-title
js-sc-current
js-sc-detail-link
```

No renombrarlas ni eliminarlas durante modificaciones visuales.

---

# 16. Enlaces

No modificar atributos:

```html
href=""
```

sin petición expresa.

Algunos enlaces pueden comenzar como:

```html
href="#"
```

y ser completados posteriormente mediante JavaScript.

Por tanto, un `href="#"` no debe considerarse automáticamente un enlace incompleto.

---

# 17. Imágenes

No modificar:

```html
src=""
```

ni expresiones dinámicas utilizadas para generar imágenes sin petición expresa.

Las imágenes pueden proceder de:

- biblioteca multimedia de WordPress
- campos de la base de datos
- relaciones Cuaderno
- expresiones `[[PARENT ...]]`

---

# 18. Base de datos

Las plantillas pueden representar datos procedentes de Oracle y/o MariaDB.

No modificar:

- nombres de tablas
- nombres de campos
- relaciones
- consultas
- esquema de datos

salvo petición expresa.

Una modificación visual nunca debe implicar automáticamente una modificación del modelo de datos.

---

# 19. Seguridad al modificar páginas

Antes de editar una página:

1. leer `page.json`
2. identificar la página WordPress
3. leer completamente el bloque que se va a modificar
4. identificar expresiones `[[...]]`
5. identificar JavaScript relacionado
6. identificar selectores funcionales
7. limitar los cambios al alcance solicitado

Después de modificar:

1. revisar el diff
2. comprobar que las expresiones `[[...]]` siguen presentes
3. comprobar HTML/CSS/JavaScript
4. ejecutar `git diff --check`
5. no hacer commit salvo petición expresa
6. no desplegar ni actualizar WordPress salvo petición expresa

---

# 20. Regla de mínima modificación

Codex debe aplicar el principio:

> Modificar únicamente lo necesario para realizar la tarea solicitada.

No aprovechar una modificación para:

- refactorizar código no relacionado
- cambiar nombres
- reorganizar bloques
- reformatear toda la página
- sustituir tecnologías
- eliminar código aparentemente redundante

sin autorización expresa.

---

# 21. WordPress es el entorno de ejecución

Los archivos contenidos en `pages/` son representaciones versionadas de posts WordPress.

La fuente ejecutada por la aplicación continúa siendo WordPress.

El flujo de desarrollo es:

```text
WordPress
    ↓ exportación
Repositorio Git
    ↓
VS Code + Codex
    ↓
revisión de cambios
    ↓
Git
    ↓
GitHub
    ↓
importación controlada
    ↓
WordPress
```

Nunca asumir que modificar `content.html` modifica automáticamente la página WordPress.

---

# 22. Norma ante dudas

Si Codex encuentra una construcción de Cuaderno que no entiende:

1. no modificarla
2. explicar qué ha encontrado
3. indicar qué necesita conocer
4. esperar instrucciones antes de alterar su comportamiento