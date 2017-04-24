'use strict'

push = Array::push

isFunction = (arg) -> typeof arg is 'function'

defaultOnResolve = (result) -> result
defaultOnReject = (reason) -> throw reason


module.exports =
class Promise

  constructor: (executor) ->
    @_reactions = []

    resolve = @_resolve true
    reject = @_resolve false

    try
      executor resolve, reject
    catch err
      reject err


  then: (onResolve, onReject) ->
    onResolve = defaultOnResolve unless isFunction onResolve
    onReject = defaultOnReject unless isFunction onReject

    new @constructor (resolve, reject) =>
      enqueue = if @_settled then setImmediate else push.bind @_reactions

      enqueue =>
        callback = if @_success then onResolve else onReject
        try
          result = callback @_result
        catch err
          return reject err
        resolve result


  catch: (onReject) ->
    @then null, onReject


  _resolve: (success) -> (result) =>
    return if @_resolved
    @_resolved = true

    if success
      if result is this
        reason = new TypeError "can't resolve a promise with itself"
        @_settle false, reason
        return

      try
        promise = @constructor._normalizeThenable result
      catch err
        @_settle false, err
        return

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

    promise or new this (resolve, reject) -> resolve value


  @reject: (reason) ->
    new this (resolve, reject) -> reject reason


  @_normalizeThenable: (arg) ->
    thenMethod = arg?.then
    return null unless isFunction thenMethod

    if arg instanceof this
      arg
    else if (typeof arg) in ['boolean', 'number']
      null
    else
      new this (resolve, reject) -> thenMethod.call arg, resolve, reject
