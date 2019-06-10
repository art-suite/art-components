# Art.Components

> Initialized by Art.Build.Configurator

### Install

```coffeescript
npm install art-components
```

## ArtComponents vs ArtReact vs React.js

Generaly, ArtComponents is designed to work just like React.js. There is
some evolution, though, which I try to note below.

## TODO

* Test and Perf RecyclableVirtualElement
* Do I make a version of Component that is .coffee so I can drop it into Zo? Or do I update all of Zo's Components to Caf?
  * Ug. I don't want to go backwards, so I think the answer is the latter.
* @extendableProperty based lifeCycle methods - at least the "Event" kind
* ArtEngine.GlobalEpochCycle should be refactored into a new, stand-alone class
  * Art.FullStackClient - or somesuch
  * It should be dependent on ArtEngine, ArtComponents, ArtModels and ArtEvents, not the other way around.
  * -- but how do we want to track perfGraphs?
  * Epoch Order: ArtEvents > ArtModels > ArtComponents > ArtEngine.State > ArtEngine.Draw
* ArtEngine really has 4 purposes; is there any conceivable way to break it up into multple NPMs?
  * they are:
    * Layout
    * User-input events
    * Drawing
    * Animation

  * problem is: user-input-events is trivial and the rest are all tighly entertwined...
