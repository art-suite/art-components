{
  defineModule
  w
  log, merge, mergeInto, clone, shallowClone
  inspect, keepIfRubyTrue, fastBind
  slice
  isObject
  isString
  isArray
  isFunction
  time
  stackTime
  countStep
  arrayWithout
  upperCamelCase
  select
  formattedInspect
  getModuleBeingDefined
  getEnv
  mergeIntoUnless
} = require 'art-standard-lib'
{createWithPostCreate} = require 'art-class-system'
{InstanceFunctionBindingMixin, globalCount} = require 'art-foundation'
{createObjectTreeFactory} = require 'art-object-tree-factory'
ReactEpoch = require './ReactEpoch'

{virtualElementPoolEnabled} = VirtualNode = require './VirtualNode'

{reactEpoch} = ReactEpoch

React = require './namespace'
{artReactDebug} = getEnv()

devMode = require './DevMode'

StateFieldsMixin = require './StateFieldsMixin'
PropFieldsMixin = require './PropFieldsMixin'

if ArtEngineCore = Neptune.Art.Engine?.Core
  # {stateEpoch} = ArtEngineCore.StateEpoch
  {globalEpochCycle} = ArtEngineCore.GlobalEpochCycle
#   onNextStateEpochReady = (f) -> stateEpoch.onNextReady f
#   timePerformance = (name, f) -> globalEpochCycle.timePerformance name, f
# else
#   onNextStateEpochReady = (f) -> reactEpoch.onNextReady f
#   timePerformance = (name, f) -> f()

# globalCount = ->
# time = stackTime = (f) -> f()

###
  React.js vs ReactArtEngine
  --------------------------

  Generaly, ReactArtEngine is designed to work just like React.js. There is
  some evolution, though, which I try to note below. -SBD

  ReactArtEngine: "Instantiation"
  -------------------------------

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

  QUESTIONS
  ---------

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

###
defineModule module, -> class Component extends PropFieldsMixin StateFieldsMixin InstanceFunctionBindingMixin VirtualNode
  @abstractClass()

  @nonBindingFunctions: w "getInitialState
    componentWillReceiveProps
    componentWillMount
    componentWillUnmount
    componentWillUpdate
    componentDidMount
    componentDidUpdate
    render"

  @resetCounters: ->
    @created =
    @rendered =
    @instantiated = 0

  @resetCounters()

  @getCounters: -> {@created, @rendered, @instantiated}

  @topComponentInstances: []
  @rerenderAll: ->
    for component in @topComponentInstances
      component.rerenderAll()
    null

  rerenderAll: ->
    @_queueRerender()
    @eachSubcomponent (component) -> component.rerenderAll()
    null

  @createAndInstantiateTopComponent: (spec) ->
    Component.createComponentFactory(spec).instantiateAsTopComponent()

  unknownModule = {}
  @createComponentFactory: (spec, BaseClass = Component) ->
    componentClass = if spec?.prototype instanceof Component
      spec
    else if spec?.constructor == Object
      _module = getModule(spec) || unknownModule
      _module.uniqueComponentNameId ||= 1

      anonymousComponentName = "Anonymous#{BaseClass.getClassName()}"
      anonymousComponentName += "_#{_module.uniqueComponentNameId++}"
      anonymousComponentName += if _module.id then "_Module#{_module.id}" else '_ModuleUnknown'

      class AnonymousComponent extends BaseClass
        @_name: anonymousComponentName

        for k, v of spec
          @::[k] = v
    else
      throw new Error "Specification Object or class inheriting from Component required."

    createWithPostCreate componentClass

  @toComponentFactory: ->
    {objectTreeFactoryOptions} = React
    {postProcessProps} = objectTreeFactoryOptions

    createObjectTreeFactory (merge objectTreeFactoryOptions,
        inspectedName: @getName() + "ComponentFactory"
        class: @
        bind: "instantiateAsTopComponent"
      ),
      (props, children) =>
        if children
          props = merge props, {children}

        instance = new @ postProcessProps props

        instance._validateChildren props?.children if devMode

        instance

  @instantiateAsTopComponent = (props, options) ->
    new @(props).instantiateAsTopComponent options

  #########################
  # HOT RELOAD SUPPORT
  #########################
  @getModule: getModule = (spec = @::)->
    spec.module || spec.hotModule || getModuleBeingDefined()

  @getCanHotReload: -> @getModule()?.hot

  @_hotReloadUpdate: (@_moduleState) ->
    name = @getClassName()
    if hotInstances = @_moduleState.hotInstances
      log "Art.React.Component #{@getName()} HotReload":
        instanceToRerender: hotInstances.length

      # update all instances
      for instance in hotInstances
        instance._componentDidHotReload()

  @postCreateConcreteClass: ({classModuleState, hotReloadEnabled})->
    super
    @_hotReloadUpdate classModuleState if hotReloadEnabled
    @toComponentFactory()

  #########################
  # INSTANCE
  #########################
  emptyProps = {}
  constructor: (props = emptyProps) ->
    Component.created++
    globalCount "ReactComponent_Created"
    super props
    @state =

    @_refs =
    @_pendingState =
    @_pendingUpdates =
    @_virtualElements = null

    @_mounted =
    @_wasMounted =
    @_epochUpdateQueued = false

  clone: ->
    new @class @props

  release: ->
    log.warn "Component released - Only a partial release for now"
    @_virtualElements?.release @
    @_virtualElements = null
    @_refs = null

  ###
  SEE: VirtualElement#withElement for more
  IN: f = (concreteElement) -> x
  OUT: promise.then (x) ->
  ###
  withElement: (f) -> @_virtualElements.withElement f

  #OUT: this
  instantiateAsTopComponent: (bindToOrCreateNewParentElementProps) ->
    Component.topComponentInstances.push @
    @_instantiate null, bindToOrCreateNewParentElementProps

  unbindTopComponent: ->
    unless 0 <= index = Component.topComponentInstances.indexOf @
      throw new Error "not a top component!"

    Component.topComponentInstances = arrayWithout Component.topComponentInstances, index
    @_unmount()

  @getter
    inspectedName: -> "#{@className}#{if @key then "-"+@key  else ''}"
    inspectedObjects: ->
      "Component-#{@inspectedName} #{@_virtualElements?.inspectedName ? '(not instantiated)'}":
        @_virtualElements?.inspectedObjectsContents ? {@props}

    mounted: -> @_mounted
    element: -> @_virtualElements?.element

    subcomponents: ->
      ret = []
      @eachSubcomponent (c) -> ret.push c
      ret

    refs: ->
      unless @_refs
        @_refs = {}
        @_virtualElements?._captureRefs @

      @_refs

  eachSubcomponent: (f) ->
    @_virtualElements?.eachInComponent (node) ->
      f node if node instanceof Component

    null

  ################################################
  # Component API (based loosly on Facebook.React)
  ################################################
  ### setState
    signatures:
      # update zero or more states via an plain object mapping keys to values;
      (newStateMapObject) ->
        sets state from each k-v pair in newStateMapObject

      # transform state during the enxt state-update epoch
      (stateUpdateFunction) ->
        during the next state-update-epoch, this function
        is applied to the state.

      # update one state-value (faster than creating an object just to update state)
      (stateKey, stateValue) ->
        set one state

    OUT: self

    stateUpdateFunction: (nextState) -> nextState
      Takes a nextState-object as input and returns a new
      nextState object or passes nextState directly through.
      EFFECT: can call setState; CANNOT modify nextState

    DEPRICATED: callback; use onNextReady
  ###
  setState: (a, b, c) ->
    if isString a
      if c
        log.warn "DEPRICATED: setState callback. Use: onNextReady"
        @onNextReady c
      return @_setSingleState a, b

    if callback = b
      log.warn "DEPRICATED: setState callback. Use: onNextReady"
      @onNextReady callback

    if newState = a
      if isFunction newState
        @_queueUpdate newState

      else
        testState = @state
        _state = null
        for k, v of newState when @_pendingState || testState[k] != v
          _state ?= @_getStateToSet()
          _state[k] = v

    @

  ### replaceState
    IN:   newState
    OUT:  newState
    DEPRICATED: callback; use onNextReady
  ###
  replaceState: (newState, callback) ->
    log.warn "DEPRICATED: replaceState. use: setState -> {}"
    @setState -> {}

  ################################################
  # Component LifeCycle
  ################################################

  ### preprocessProps

    When:         Called on component instantiation and any time props are updated

    IN:           newProps - The props received from the render call which created/updated this component

    OUT:          plain Object - becomes @props. Can be newProps, based on newProps or entirely new.

    Guarantee:    @props will allways be passed through preprocessProps before it is set.
                  i.e. Your render code will never see a @props that hasen't been preprocessed.

    Be sure your preprocessProps: (requirements)
      - returns a plain Object
      - doesn't modify the newProps object passed in (create and return new object to add/alter props)
      - call super!

    Examples:
      # minimal
      preprocessProps: ->
        merge super, myProp: 123

      # a little of everything
      preprocessProps: ->
        newProps = super
        @setState foo: newProps.foo
        merge newProps, myProp: "dude: #{newProps.foo}"

    Okay:
      you can call @setState (Art.Flux.Component does exactly this!)

    Description:
      Either return exactly newProps which were passed in OR create a new, plain object.
      The returned object can contain anything you want.
      These are the props the component will see in any subsequent lifecycle calls.

    NOTE: Unique to Art.React. Not in Facebook's React.

    NOTES RE Facebook.React:
      Why add this? Well, often you want to apply a transformation to @props whenever its set OR it changes.
      With Facebook.React there is no one lifecycle place for this. Component instantiation/mounting
      and component updating are kept separate. I have found it is very error-prone to implement
      this common functionality manually on each component that needs it.
  ###
  preprocessProps: defaultPreprocessProps = (newProps) -> newProps

  ### preprocessState
    When:         preprocessState is called:
                    immediatly after getInitialState
                    after preprocessProps
                    after componentWillUpdate
                    before rendering

    IN:           newState - the state which is proposed to become @state
    OUT:          object which will become @state. Can be newState, be based on newState or completely new.

    Guarantees:   @state will allways be passed through preprocessState before it is set.
                  i.e. Your render code will never see a @state that hasen't been preprocessed.

    NOTES RE Facebook.React:
      Why add this? Well, often you want to apply a transformation to @state whenever it is initialized
      OR it changes. With Facebook.React there is no one lifecycle place for this. Component
      instantiation/mounting and component updating are kept separate. I have found it is very
      error-prone to implement this common functionality manually on each component that needs it.

      An example of this is FluxComponents. They alter state implicitly as the subscription data comes in, and
      and component instantiation. preprocessState makes it easy to transform any data written via FluxComponents
      into a standard form.

    SBD NOTES TO SELF:
      I think:
        - it is OK to directly mutate newState, can we declare this offically part of the API?
        - calls to @setState in preprocessState will be applied NEXT epoch.
        - could make getInitialState obsolete, but I think we'll keep it around for convenience and consistency
  ###
  preprocessState: defaultPreprocessState = (newState) -> newState

  ### componentWillMount
    Invoked once immediately before the initial rendering occurs.
    ALLOWED: setState
    IN/OUT: ignored
  ###
  componentWillMount: defaultComponentWillMount = ->

  ### componentWillUnmount
    Invoked immediately before a component is unmounted.
    Perform any necessary cleanup things that were created in componentDidMount.
    IN/OUT: ignored
  ###
  componentWillUnmount: defaultComponentWillUnmount = ->

  ###
    Called each time webpack hot-reloads a module.
    It is important that this change the components state to trigger a rerender.
  ###
  componentDidHotReload: ->
    count = (@state._hotModuleReloadCount || 0) + 1
    @setState _hotModuleReloadCount: count

  ################################################
  # DEPRICATED Component LifeCycle
  ################################################
  # DEPRICATED
  # Called when the component is instantiated.
  # ReactArtEngine ONLY: you CAN call setState/setSingleState during getInitialState:
  #   * setState calls populate @_pendingState and are merged after getInitialState: @state = merge @getInitialState(), @_pendingState
  #   * a reactEpoch cycle is not queued; the only significant expense is one extra object creation to store the @_pendingState
  getInitialState: defaultGetInitialState = -> {}

  ###
    DEPRICATED
    Invoked once immediately after the initial rendering occurs.
  ###
  componentDidMount: defaultComponentDidMount = ->

  ###
    DEPRICATED - preprocessProps makes this obsolete
    Invoked when a component is receiving new props. This method is not called
    for the initial render.

    Use this as an opportunity to react to a prop transition before render()
    is called by updating the state using this.setState(). The old props can
    be accessed via this.props. Calling this.setState() within this function
    will not trigger an additional render.
  ###
  componentWillReceiveProps: defaultComponentWillReceiveProps = (newProps) ->

  # DEPRICATED - preprocessState makes this obsolete
  # Invoked immediately before rendering when new props or state are being
  # received. This method is not called for the initial render.
  #
  # Use this as an opportunity to perform preparation before an update occurs.
  #
  # Note: You cannot use @setState() in this method. If you need to update
  # state in response to a prop change, use componentWillReceiveProps instead.
  #
  # ReactArtEngine-specific: if newProps == @props then props didn't change; same with newState
  componentWillUpdate: defaultComponentWillUpdate = (newProps, newState)->

  # DEPRICATED - use @render, check if not-first render; if you care
  # Invoked immediately after updating occurs. This method is not called for the initial render.
  # Use this as an opportunity to operate on the AIM when the component has been updated.
  #
  # ReactArtEngine-specific: if newProps == @props then props didn't change; same with newState
  componentDidUpdate: defaultComponentDidUpdate = (oldProps, oldState)->

  ######################
  # ART REACT EXTENSIONS
  ######################

  ### find - find components in this branch of the VirtualTree that match pattern
    IN
      pattern: one of:
        <String>
        <RegExp>
        (testString) -> t/f

      options:
        findAll: t/f  # by default find won't return children of matching Elements, set to true to return all matches
        verbose: t/f  # log useful information on found objects

      matches: internal use

    OUT: <Array Components>
  ###
  find: (pattern, options, matches = []) ->
    {findAll, verbose} = options if options?

    if matchFound = @testMatchesPattern pattern
      if verbose
        log if usedFunction
              matched: @inspectedName, functionResult: functionResult
        else  matched: @inspectedName
      matches.push @
    else if verbose == "all"
      log if usedFunction
            notMatched: @inspectedName, functionResult: functionResult
      else  notMatched: @inspectedName

    if !matchFound || findAll
      @eachSubcomponent (child) ->
        child.find pattern, arguments[1], matches
    matches

  findElements: (pattern, options, matches = []) ->

    if @_virtualElements
      if options?.verbose
        log "findElements in #{@inspectedName}"
      @_virtualElements.findElements pattern, options, matches

    matches

  getPendingState: -> @_pendingState || @state

  ######################
  # PRIVATE
  ######################
  _captureRefs: (component) ->
    if component == @renderedIn
      if key = @key
        component._refs[key] = @
      if @props.children
        for child in @props.children
          child._captureRefs component
    null

  _getStateToSet: ->
    if @_wasMounted then @_getPendingState()
    else
      @state = {} if @state == emptyState
      @state

  _setSingleState: (stateKey, stateValue, callback) ->
    if @_pendingState || @state[stateKey] != stateValue
      @_getStateToSet()[stateKey] = stateValue

    stateValue

  _queueRerender: ->
    @_getPendingState()

  ### _setPendingState
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
        render runs, removing the child Component. Then ArtReact detects the child needs unmounting, but just
        before it unmounts it, the child gets a re-render as-if it's props changed, though they didn't. This
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

    DO WE NEED SOMETHING MORE POWERFUL?

      - Do we need more than 1 "final render" - during animating-out?
      - Do we need an animating-out-done render?
      - A general solution would be a "manual unmount" option. I don't love this, but
        I also don't love tying this explicitly to ArtEngine's animating-out features.

    To ENABLE updates on unmounted Components, remove: || !@_mounted
  ###
  _setPendingState: (pendingState) ->
    @_queueChangingComponentUpdates()
    @_pendingState = pendingState

  _queueChangingComponentUpdates: ->
    unless @_epochUpdateQueued
      @_epochUpdateQueued = true
      reactEpoch.addChangingComponent @

  _queueUpdate: (updateFunction) ->
    @_queueChangingComponentUpdates()
    (@_pendingUpdates ?= []).push updateFunction

  _getPendingState: ->
    @_pendingState || @_setPendingState {}

  _unmount: ->
    @_removeHotInstance()
    @_componentWillUnmount()

    @_virtualElements?._unmount()
    @_mounted = false

  _addHotInstance: ->
    if moduleState = @class._moduleState
      (moduleState.hotInstances ||= []).push @

  _removeHotInstance: ->
    if moduleState = @class._moduleState
      {hotInstances} = moduleState
      if hotInstances && 0 <= index = hotInstances.indexOf @
        moduleState.hotInstances = arrayWithout hotInstances, index

  #OUT: this
  emptyState = {}
  _instantiate: (parentComponent, bindToOrCreateNewParentElementProps) ->
    if parentComponent != @renderedIn && parentComponent? && @renderedIn?
      log "Component clone on instantiate: #{parentComponent?.inspectedNameAndId} #{@renderedIn?.inspectedNameAndId}"
      # return @clone()._instantiate parentComponent, bindToOrCreateNewParentElementProps

    super
    globalCount "ReactComponent_Instantiated"
    @bindFunctionsToInstance()

    @state ?= emptyState

    @props = @_preprocessProps @props

    @_addHotInstance()
    @_componentWillMount()

    if defaultGetInitialState != @getInitialState
      log.warn "DEPRICATED getInitialState: use @stateFields() or preprocessState()"
      initialState = @getInitialState()

    __state = @state
    @state = emptyState

    @state = @_preprocessState merge @getStateFields(), __state, initialState

    @_instantiateVirtualElements bindToOrCreateNewParentElementProps

    @_componentDidMount()
    @_wasMounted = @_mounted = true
    @

  _instantiateVirtualElements: (bindToOrCreateNewParentElementProps) ->
    if @_virtualElements = @_render()
      @_virtualElements._instantiate @, bindToOrCreateNewParentElementProps

  _render: ->
    # <performance monitoring>
    Component.rendered++
    start = globalEpochCycle?.startTimePerformance()
    globalCount "ReactComponent_Rendered"
    log "render component: #{@className}" if artReactDebug
    # </performance monitoring>

    @_refs = null
    VirtualNode.currentlyRendering = @
    try
      rendered = @render()
      throw new Error "#{@className}: render must return a VirtualNode. Got: #{inspect rendered}" unless rendered instanceof VirtualNode
    catch error
      log.error "Error rendering #{@inspectedPath}", error
      rendered = null

    VirtualNode.currentlyRendering = null

    # <performance monitoring>
    globalEpochCycle?.endTimePerformance "reactRender", start
    # </performance monitoring>

    rendered

  _canUpdateFrom: (b)->
    @class == b.class &&
    @key == b.key

  _shouldReRenderComponent: (componentInstance) ->
    @_propsChanged(componentInstance) || @_pendingState

  # renders the component and updates the Virtual-AIM as needed.
  _reRenderComponent: ->

    unless @_virtualElements
      @_instantiateVirtualElements()
    else if newRenderResult = @_render()

      if @_virtualElements._canUpdateFrom newRenderResult
        log "Component._reRenderComponent _updateFrom #{newRenderResult.inspectedName}/#{newRenderResult.uniqueId}"
        @_virtualElements._updateFrom newRenderResult

      else
        # TODO - this should probably NOT be an error, but it isn't easy to solve.
        # Further, this is wrapped up with the pending feature of optionally returing an array of Elements from the render function.
        # Last, this should not be special-cased if possible. VitualElement children handling code should be used to handle these updates.

        console.error """
          REACT-ART-ENGINE ERROR - The render function's top-level Component/VirtualElement changed 'too much.' The VirtualNode returned by a component's render function cannot change its Type or Key.

          Solution: Wrap your changing VirtualNode with a non-changing VirtualElement.

          Offending component: #{@classPathName}
          Offending component assigned to: self.offendingComponent
          """
        console.log "CHANGED-TOO-MUCH-ERROR-DETAILS - all these properties must be the same on the oldRoot and newRoot",
          oldRoot: select @_virtualElements, "key", "elementClassName", "class"
          newRoot: select newRenderResult, "key", "elementClassName", "class"
        self.offendingComponent = @
        @_virtualElements?._unmount()
        (@_virtualElements = newRenderResult)._instantiate @

  # 1. Modifies @ to be an exact clone of componentInstance.
  # 2. Updates the true-Elements as we go.
  # 3. returns @
  _updateFrom: (componentInstance) ->
    if @_shouldReRenderComponent componentInstance
      globalCount "ReactComponent_UpdateFromTemporaryComponent_Changed"
      @_applyPendingState componentInstance.props
    else
      globalCount "ReactComponent_UpdateFromTemporaryComponent_NoChange"

    @

  ### _resolvePendingUpdates
    Clears out @_pendingUpdates and @_pendingState, applying them all to 'state' as passed-in.

    NOTE:
      This is a noop if @_pendingUpdates and @_pendingState are null.
      OldState is returned without any work done.

    ASSUMPTIONS:
      if @_pendingState is set, it is an object we are allowed to mutate
        It will be mutated and be the return-value of this function.

    IN:
      oldState - the state to update

    EFFECTS:
      oldState is NOT modified
      @_pendingState and @_pendingUpdates are null and have been applied to oldState

    OUT: state is returned as-is unless @_pendingState or @_pendingUpdates is set
  ###
  _resolvePendingUpdates: (oldState = @state)->
    if @_pendingState
      newState = mergeIntoUnless @_pendingState, oldState
      @_pendingState = null

    if @_pendingUpdates
      newState ?= merge oldState

      for updateFunction in @_pendingUpdates
        newState = updateFunction.call @, newState

      @_pendingUpdates = null

    newState ? oldState


  ### _applyPendingState
    NOTES:
      - newProps is non-null if this component is being updated from a non-instantiated Component.
      - This is where @props gets set for any update, but not where it gets set for component initializiation.

    NOTE: User-overridable @componentWillReceiveProps is allowed to call @setState.
      @componentWillReceiveProps is DEPRICATED. use @preprocessProps

    NOTE: Any updates state-changes triggered in @componentDidUpdate will be delayed until next epoch
      @componentDidUpdate is DEPRICATED. use @render, check if not-first render; if you care

  ###
  _applyPendingState: (newProps) ->
    return unless @_epochUpdateQueued || newProps

    oldProps = @props
    oldState = @state

    if newProps
      newProps = @_preprocessProps @_rawProps = newProps

      @_componentWillReceiveProps newProps
    else
      newProps = oldProps

    @_updateComponent newProps, @_resolvePendingUpdates()

    @_reRenderComponent()

    @_componentDidUpdate oldProps, oldState


  ### _updateComponent
    IN:
      newProps: if set, replaces props
      newState:

    NOTE: @componentWillUpdate
      @componetWillUpdate is DEPRICATED - use preprocessState
      User-overridable @componentWillUpdate is allowed to call @setState.
      Any updates state-changes triggered in @componentWillUpdate will be applied immediately
      after @componetWillUpdate completes. The newState object passed to @componetWillUpdate is
      not modified.

      IMPLEMENTATION NOTES:
        @_resolvePendingUpdates is used here to immediately apply any changes @_componentWillUpdate caused.
        However, if it didn't cause any changes, it's a noop.
        Performance FYI: If @_componentWillUpdate triggers any changes, one new object will be created.

        @_epochUpdateQueued is cleared AFTER @_componentWillUpdate so calls to @setState
        IN @_componentWillUpdate won't actually trigger an epoch.

    NOTE: @preprocessState
      User-overridable @preprocessState is allowed to call @setState.
      Any updates state-changes triggered in @preprocessState will be delayed until next epoch
      @_preprocessState assumes @props has already been updated

  ###
  _updateComponent: (newProps, newState) ->

    @_componentWillUpdate newProps, newState

    newState = @_resolvePendingUpdates newState
    @_epochUpdateQueued = false
    @props = newProps

    @state = @_preprocessState newState

  ########################
  # PRIVATE
  # LifeCycle Management
  ########################

  ###
    NOTE: The reason for defaultComponent* values instead of making the defaults NULL
      is so inheritors can call "super" safely.
    IDEA: We could make createComponentFactory gather up all custom life-cycle functions,
      and execute each in sequence therefor they don't need to call super.
      We could also enable mixins this way.
    2019: Better - let's make these lifecycle functions @extendableProperties
  ###

  _preprocessProps: (props) ->
    props = super props # triggers PropFieldsMixin - which will include any default values from @propFields
    return props if defaultPreprocessProps == @preprocessProps
    try
      @preprocessProps props
    catch error
      log ArtReact_preprocessProps: {Component: @, error}
      console.log error
      props

  _preprocessState: (state) ->
    return state if defaultPreprocessState == @preprocessState
    try
      @preprocessState state
    catch error
      log ArtReact_preprocessState: {Component: @, error}
      console.log error
      state

  _componentDidHotReload: ->
    @bindFunctionsToInstance true
    try @componentDidHotReload()

  _componentWillMount: ->
    return if defaultComponentWillMount == @componentWillMount
    @componentWillMount()

  _componentWillUnmount: ->
    return if  defaultComponentWillUnmount == @componentWillUnmount
    @componentWillUnmount()

  _componentDidMount: ->
    return if defaultComponentDidMount == @componentDidMount
    log.warn "DEPRICATED: _componentDidMount - use componentWillMount"
    @onNextReady =>
      @componentDidMount()

  _componentWillReceiveProps: (newProps) ->
    return if defaultComponentWillReceiveProps == @componentWillReceiveProps
    log.warn "DEPRICATED: _componentWillReceiveProps - use preprocessProps"
    @componentWillReceiveProps newProps

  _componentWillUpdate: (newProps, newState)->
    return if defaultComponentWillUpdate == @componentWillUpdate
    log.warn "DEPRICATED: _componentWillUpdate - use preprocessProps / preprocessState"
    @componentWillUpdate newProps, newState

  _componentDidUpdate: (oldProps, oldState)->
    return if defaultComponentDidUpdate == @componentDidUpdate
    log.warn "DEPRICATED: _componentDidUpdate - use 'render' - it's called at exactly the same times - except for the first render"
    @onNextReady =>
      @componentDidUpdate oldProps, oldState
