{defineModule, log, mergeInto, each, lowerCamelCase} = require 'art-standard-lib'

defineModule module, -> (superClass) -> class StateFieldsMixin extends superClass


  @extendableProperty stateFields: @emptyStateFields = {}

  ###
    Declare state fields you intend to use.
    IN: fields
      map from field names to initial values

    EFFECTS:
      used to initialize @state
      declares @getters and @setters for each field
      for fieldName, declares:
        @getter :fieldName
        @setter :fieldName

        if initial value is true or false:
          toggleFieldName:  -> @fieldName = !@fieldName
          setIsFieldName:   -> @fieldName = true
          clearFieldName:   -> @fieldName = false
          triggerFieldName: -> @fieldName = true

        else
          clearFieldName: -> @fieldName = null

  ###
  @stateFields: sf = (fields) ->
    @extendStateFields fields
    each fields, (initialValue, field) =>
      defaultSetValue = initialValue
      clearValue = null

      @addGetter field, -> @state[field]

      if initialValue == true || initialValue == false
        clearValue = false
        defaultSetValue = true

        # boolean setter
        @addSetter field, (v) ->
          @setState field, !!v

        # boolean set-true: setIsFoo (DEPRICATED)
        @::[lowerCamelCase "set is #{field}"] = ->
          log.warn "StateFieldsMixin #{lowerCamelCase "set is #{field}"} is DEPRICATED. Use: #{lowerCamelCase "trigger #{field}"}."
          @setState field, true

        # boolean set-true: triggerFoo
        @::[lowerCamelCase "trigger #{field}"] = ->
          @setState field, true

        # boolean toggle
        @::[lowerCamelCase "toggle #{field}"] = ->
          @setState field, !@state[field]

      else
        @addSetter field, (v) ->
          # SBD 2018-06-22: I think we should change this:
          #   v == null >> reset to default
          #   v == undefined >> ignored
          # OR
          #   no interpretation - just a normal setter
          #   I'm leaning towards this. I had a bug where I was setting a value with undefined and nothing happend.
          #   That was unexpected, even though reasonable.
          @setState field, if v == undefined then defaultSetValue else v

      @::[lowerCamelCase "clear #{field}"] = ->
        @setState field, clearValue

  # ALIAS
  @stateField: sf
