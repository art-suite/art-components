{
  log, compact, globalCount, flatten, BaseObject, shallowClone, inspect, objectKeyCount, isObject, deepEach, isPlainObject, keepIfRubyTrue,
  propsEq
  defineModule
  isFunction
} = require './StandardImport'
{componentEpoch} = require './ComponentEpoch'

emptyObject = {}
defineModule module, class VirtualNode extends BaseObject
  onNextReady: (f, forceEpoch = true) -> componentEpoch.onNextReady f, forceEpoch, @

  @virtualElementPoolEnabled = false

  # @assignRefsTo: null
  @currentlyRendering: null

  constructor: (props) ->
    @_initVirtualNode props

  _initVirtualNode: (props) ->
    @_released = false
    @_parentComponent = null
    @_renderedIn = VirtualNode.currentlyRendering

    @key = if props?
      props.key
    else
      props = emptyObject
      null

    @props = @_rawProps = props
    @_propsLength = -1

    # created once, then never changes
    @element = null

    # VirtualNode._assignRefs @

  @getter "rawProps reusable parentComponent renderedIn",
    inspectedName: -> "VirtualNode<#{@key}>"
    inspectedNameAndId: -> "#{@inspectedName}-#{@uniqueId}"
    inspectedPath: ->
      (if @parentComponent
        @parentComponent.inspectedPath + "/"
      else
        ""
      ) + @inspectedName

    propsLength: ->
      if @_propsLength >= 0
        @_propsLength
      else
        @_propsLength = objectKeyCount @props

  @setter
    propsLength: (v)-> @_propsLength = v

  eachInComponent: (f) -> f @

  checkin: ->

  release: ->
    throw new Error "VirtualNode.release: already released #{@inspectedNameAndId}" if @_released

    if @_parentComponent == @_renderedIn
      # log " VirtualNode.release<#{@inspectedName}-#{@uniqueId}>: releasing"
      @_resetAllProps()
      @checkin()
    # else
    #   log " VirtualNode.release<#{@inspectedName}-#{@uniqueId}>: not releasing"
    @

  _resetVirtualNodeProps: ->
    @_released = true
    @_propsLength = -1
    @_parentComponent =
    @key =
    @props = @_rawProps =
    @element = null

  _resetAllProps: ->
    @_resetVirtualNodeProps()

  testMatchesPattern: (pattern, testString) ->

    if isFunction pattern
      !!pattern @
    else
      (testString ? @inspectedName).match pattern

  ###
  Evaluate "f" in the thread the Element exists in.

  Example: For when React is running in a web-worker and the element
  is on the main threa.

  IN: (element) -> plainObjects
  OUT: promise returning function's plain-object-result

  # TODO: add worker support
  ###
  withElement: (f) ->
    new Promise (resolve) =>
      resolve f @element

  ###
  Lighter-weight than "withElement"

  IN:
    method: string
    args: 0 or more additional arguments
  OUT: promise returning function's plain-object-result

  Equivelent to:
    @withElement (element) -> element[method] args...

  ###
  sendToElement: (method, args...) ->
    new Promise (resolve) =>
      resolve @element[method] args...

  #####################
  # PRIVATE
  #####################
  @_separateConstructionParams: (args, propsOut, childrenOut) ->
    deepEach args, (obj) ->
      if isPlainObject obj
        propsOut[k] = v for k, v of obj
      else if keepIfRubyTrue obj
        childrenOut.push obj

  # @_assignRefs: (node) ->
  #   if (key = node.key) && @assignRefsTo
  #     if @assignRefsTo[key] # TODO: This should probably be disabled unless in dev-mode
  #       console.warn """
  #         WARNING: Duplicate key found. This MUST be fixed for correct operation.
  #           key: #{inspect key}
  #           new VirtualNode: #{node.inspectedName}
  #           old VirtualNode: #{@assignRefsTo[key].inspectedName}
  #         """
  #     else
  #       @assignRefsTo[key] = node

  # TODO: only run in dev mode
  _validateChildren: (children) ->
    return children unless children
    for child in children
      unless child instanceof VirtualNode
        console.warn "invalid VirtualNode child": child, parent:@
        console.warn "Hint: Did you place properties AFTER a child element?" if isObject child
        throw new Error "VirtualNode child is not a VirtualNode.\ninvalid child: #{inspect child}\nparent: #{@inspectedName}"
    children

  _propsChanged: (virtualNode) ->
    newProps = virtualNode.rawProps
    _propsLength = 0

    # return true if an existing prop changed
    for k, v of @rawProps
      _propsLength++
      # global.propsEq = (global.propsEq | 0) + 1 if propsEq v, newProps[k]
      # global.justEq = (global.justEq | 0) + 1 if v == newProps[k]
      # global.testEq = (global.testEq | 0) + 1

      # return true unless v == newProps[k] # propsEq - seems to be more overhead than its worth
      return true unless propsEq v, newProps[k]
    @_propsLength = _propsLength

    # props
    _propsLength != virtualNode.getPropsLength()

  # Post conditions:
  #   This and its entire Virtual-AIM sub-branch has been updated to be an exact clone of sourceNode,
  #   except it is _instantiated and the True-AIM is fully updated as well.
  # returns this
  _updateFrom: (sourceNode) ->

  # return true if _updateFrom can work with sourceNode
  _canUpdateFrom: (sourceNode) -> false

  # Post conditions:
  #   @element is set
  #   Virtual-AIM sub-branch is fully generated
  #   All True-AIM elements have been created and assembled
  # returns this
  _instantiate: (parentComponent) ->
    # unless !parentComponent? || parentComponent instanceof VirtualNode
    #   log.error {parentComponent, self: @}
    #   throw new Error "not right"
    @_parentComponent = parentComponent
    @
