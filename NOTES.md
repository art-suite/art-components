# TODO
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


# NOTES

## Questions

Updates to unmounted components???
```
2016-12: I can't decide! Should we allow state updates on unmounted components or not?!?!
RELVANCE: allowing state updates allows us to update animating-out Art.Engine Elements.
This is useful, for example, to hide the TextInput Dom element

I'm generally against updating unmounted components:
  - they don't get new props. Logically, since they are unmounted,
    they should have no props, yet they do. They would surely
    completely break if we set @props = {}.

  - Since they don't get new @props, there is no way for the parent-before-unmounting
    to control unmounted Components. If their state can change, their parent-before
    should have some control.

BUT, we need a better answer for animating-out Components. There is a need for re-rendering them
at the beginning and ending of their animating-out process.

Animating-Out
  - Most things can probably be handled by 1 render just before animating-out starts. This
    is awkward to do manually: First render decides we are going to remove a sub-component, but
    doesn't - during that render - instead it tells that component it is about to be animated-out.
    Then, it queues another render where it actually removes the sub-component. And this must all
    be managed by the parent Component, when really it's 100% the child-component's concern.

  - What if a Component can request a "final render" just BEFORE it is unmounted? The parent Component's
    render runs, removing the child Component. Then ArtComponents detects the child needs unmounting, but just
    before it unmounts it, the child gets a re-render as-if its props changed, though they didn't. This
    in turn will update any Element or child Components for their animating-out state. After that,
    the component will get no more renders - since it will then be unmounted and unmounted components don't
    get rendered.

  - Further, when we do this final render, we can signal it is "final" via @props.
    - have the component get a final-render notification (via a member function override).
      That function takes as inputs the last-good @props, and returns the final-render @props.
      If it returns null, there will be no final render. This is the default implementation.

    - I LIKE!

  - Conclusion: New Component override: (TODO - I think we should go for this solution!)

      finalRenderProps: (previousProps) -> null

    To request a final-render, all you need to do is add this to your Component:

      finalRenderProps: (previousProps) -> previousProps

    And you may find it handy to also do:

      finalRenderProps: (previousProps) -> merge previousProps, finalRender: true

    Then you can do something special for your final-render:

      render: ->
        {finalRender} = @props

        if finalRender ...

  - 2019: i see no need to overload props for this. How about a "finalRender" method?
    Normally it does nothing, but if implemented and it returns a render-result (VirtualNode),
    then ArtComponents runs _reRenderAndUpdateComponent, but with the finalRender
    result.

DO WE NEED SOMETHING MORE POWERFUL?

  - Do we need more than 1 "final render" - during animating-out?
  - Do we need an animating-out-done render?
  - A general solution would be a "manual unmount" option. I don't love this, but
    I also don't love tying this explicitly to ArtEngine's animating-out features.

```

## Ideas

* let's make these lifecycle functions @extendableProperties
