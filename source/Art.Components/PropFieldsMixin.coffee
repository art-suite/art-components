{formattedInspect, defineModule, isString, isArray, log, object, each, isPlainObject, merge, mergeInto} = require 'art-standard-lib'

defineModule module, -> (superClass) -> class PropFieldsMixin extends superClass

  normalizePropFieldValue = (name, value) ->
    default: value

  @extendableProperty(
    propFields: null

    # custom extender here only so propFiles can be initialized to null, not {}.
    # This is a performance optimization, but I'm dubious about if it does anything.
    # Need a concrete perf test to be sure, but I think we can just simplified all this down to propFields: {}
    # SBD (2018-Feb)
    extend: (extendedValue, addPropFields) ->
      mergeInto extendedValue ? {}, addPropFields
  )

  ###
  Declare prop fields you intend to use.
  IN: fields
    map from field names to:
      default-values

  FUTURE-NOTE:
    If we decide we want more options than just 'default-values',
    we can add a new declarator: @propFieldsWithOptions
    where the map-to-values must all be options objects.

  EFFECTS:
    used to define getters for @prop
  ###
  @propFields: sf = (fields, b...) ->
    if isString fields
      @propFields "#{fields}": null

    else if isArray fields
      @propFields f for f in fields

    else if isPlainObject
      @extendPropFields fields
      each fields, (defaultValue, field) =>
        @addGetter field, -> @props[field]

    else
      throw new Error "invalid propFields type: #{formattedInspect fields}"

    if b.length > 0
      @propFields b

  # ALIAS
  @propField: sf

  # could use: pureMerge @getPropFields(), props
  # but I'm concerned about performance.
  _preprocessProps: (props) ->
    if propFields = @getPropFields()
      out = {}
      out[k] = v for k, v of propFields
      out[k] = v for k, v of props
      out
    else props
