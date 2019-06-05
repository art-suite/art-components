# Art.Components

> Initialized by Art.Build.Configurator

### Install

```coffeescript
npm install art-components
```

## ArtComponents vs React.js

Generaly, ArtComponents is designed to work just like React.js. There is
some evolution, though, which I try to note below.

### ArtComponents: "Instantiation"

This is not a concept in React.js. It isn't important to the client, but it
is useful to understand in the implementation.

In-short: a non-instantiated component only has properties. It doesn't have
state and it isn't rendered. An instantiated component has state and gets
rendered at least once.

When a component is used in a render function, and with every re-render,
an instance-object is created with standard javascript "new ComponentType."
However, that component instance is only a shell - it contains the
properties passed into the constructor and nothing else.

Once the entire render is done, the result is diffed against the current
VirtualElements. The component instance is compared against existing components
via the diff rules. If an existing, matching component exists, that
component is updated and the new instance is discard. However, if an
existing match doesn't exist, then the new component instance is
"instantiated" and added to the VirtualElements.

### QUESTIONS

I just discovered it is possible, and useful, for a component to be rendered
after it is unmounted. I don't think this is consistent with Facebook-React.

Possible: if @setState is called after it is unmounted, it will trigger a
render. This can happen in FluxComponents when a subscription updates.

Useful: Why does this even make sense? Well, with Art.Engine we have
removedAnimations. That means the element still exists even though it has been
"removed." It exists until the animation completes. It is therefor useful to
continue to receive updates from React, where appropriate, during that "sunset"
time.

Thoughts: I think this is OK, though this changes what "unmounted" means. I just
fixed a bug where @state got altered without going through preprocessState first
when state changes after the component was unmounted. How should I TEST this???
