# Art.Components

> Initialized by Art.Build.Configurator

### Install

```coffeescript
npm install art-components
```

## ArtComponents vs ArtReact vs React.js

Generaly, ArtComponents is designed to work just like React.js. There is
some evolution, though, which I try to note below.

## Component API

### `preprocessState`

Often you want to apply a transformation to `@state` whenever it is initialized
OR it changes.

An example of this is FluxComponents. They alter state implicitly as the subscription data comes in, and
and component instantiation. preprocessState makes it easy to transform any data written via FluxComponents
into a standard form.
