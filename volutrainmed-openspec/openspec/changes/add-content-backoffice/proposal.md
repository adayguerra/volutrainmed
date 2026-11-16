# Proposal

## Why

El valor del producto depende de un contenido amplio, correcto y adaptado a cada sector. Ese contenido lo crean farmacólogos y docentes, no desarrolladores, y debe poder corregirse el mismo día en que se detecta un error.

Hace falta un back office con el que un administrador no técnico cargue preguntas, defina ejercicios que generan cientos de variantes y los publique sin tocar código ni esperar a una versión de la app, con la garantía de que un experto distinto del autor lo ha validado todo.

Fase 1. Depende de `add-training-app-mvp` (la app consume los paquetes que este cambio produce). `add-house-ads-and-premium` usa su ciclo de revisión y publicación para las campañas.

## What Changes

- Aplicación web de administración con roles, doble factor y registro de auditoría.
- Gestión del árbol de sectores, itinerarios, unidades y lecciones.
- Editor de plantillas parametrizadas: variables, rangos, tabla de casos, fórmula con comprobación dimensional, unidades, tolerancia, errores previsibles y pasos de la explicación.
- Editor de preguntas fijas e importación masiva desde hoja de cálculo.
- Vista previa en móvil y tablet con lectura en voz alta y simulación de respuestas habladas.
- Ciclo de revisión con lista de comprobación, firma y caducidad de la validación.
- Publicación versionada: generación de variantes, doble cálculo, paquete firmado, despliegue gradual, reversión y retirada inmediata.
- Gestión de usuarios, consultas, catálogos de unidades y de voz, y analítica de contenido.

## Capabilities

### New Capabilities

- `content-authoring`: creación de la estructura y de los ejercicios sin código, con plantillas parametrizadas, preguntas fijas, importación masiva y vista previa con voz.
- `content-review-publishing`: validación por un experto, versionado, publicación de paquetes, despliegue gradual, reversión y retirada.
- `backoffice-administration`: roles y permisos, auditoría, panel de control, usuarios, consultas, catálogos y analítica de contenido.

### Modified Capabilities

Ninguna.

## Impact

- **Código**: aplicación web nueva en React y TypeScript; biblioteca del motor de plantillas; servicio de publicación.
- **API y datos**: tablas de contenido, revisiones, versiones, paquetes y auditoría; almacenamiento y red de distribución para los paquetes.
- **Personas**: exige revisores expertos acreditados por sector. Es el principal cuello de botella previsible.
- **Control de cambios regulatorio**: el back office refuerza el límite formativo. Toda plantilla lleva la pauta como dato, y la revisión rechaza textos que sugieran uso clínico.
