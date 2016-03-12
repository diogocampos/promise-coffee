'use strict'

push = Array::push

isFunction = (arg) -> typeof arg is 'function'

defaultOnFulfill = (result) -> result
defaultOnReject = (reason) -> throw reason


module.exports =
class Promise

  constructor: (executor) ->
    @_reactions = []

    fulfill = @_resolve true
    reject = @_resolve false

    try
      executor fulfill, reject
    catch err
      reject err


  then: (onFulfill, onReject) ->
    onFulfill = defaultOnFulfill unless isFunction onFulfill
    onReject = defaultOnReject unless isFunction onReject

    new @constructor (fulfill, reject) =>
      enqueue = if @_settled then setImmediate else push.bind @_reactions

      enqueue =>
        callback = if @_success then onFulfill else onReject
        try
          result = callback @_result
        catch err
          return reject err
        fulfill result


  catch: (onReject) ->
    @then null, onReject


  _resolve: (success) -> (result) =>
    return if @_resolved
    @_resolved = true

    if success
      if result is this
        reason = new TypeError "can't resolve a promise with itself"
        return @_settle false, reason

      try
        promise = @constructor._normalizeThenable result
      catch err
        return @_settle false, err

      if promise  # resolved with a thenable
        promise.then (result) =>
          @_settle true, result
        ,(reason) =>
          @_settle false, reason
        return

    # resolved with a non-thenable or rejected
    @_settle success, result


  _settle: (success, result) ->
    return if @_settled
    @_settled = true

    @_success = success
    @_result = result

    setImmediate reaction for reaction in @_reactions
    @_reactions = null


  @resolve: (value) ->
    try
      promise = @_normalizeThenable value
    catch err
      return @reject err

    promise or new this (fulfill, reject) -> fulfill value


  @reject: (reason) ->
    new this (fulfill, reject) -> reject reason


  @_normalizeThenable: (arg) ->
    thenMethod = arg?.then
    return false unless isFunction thenMethod

    if arg instanceof this
      arg
    else if (typeof arg) in ['boolean', 'number']
      false
    else
      new this (fulfill, reject) -> thenMethod.call arg, fulfill, reject
