'use strict'

push = Array::push

isArray = Array.isArray
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


  finally: (callback) ->
    constructor = @constructor
    @then (value) ->
      constructor.resolve(callback()).then -> value
    ,(reason) ->
      constructor.resolve(callback()).then -> throw reason


  done: (onFulfill, onReject) ->
    promise = if onFulfill or onReject then @then onFulfill, onReject else this
    promise.catch (reason) ->
      setImmediate -> throw reason


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

      if promise  # resolved with thenable
        return promise
          .then (result) =>
            @_settle true, result
          ,(reason) =>
            @_settle false, reason

    # resolved with non-thenable or rejected
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


  @_normalizeThenable: (arg) ->
    thenMethod = arg?.then
    if isFunction thenMethod
      if arg instanceof this
        arg
      else if (typeof arg) in ['boolean', 'number']
        false
      else
        new this (fulfill, reject) -> thenMethod.call arg, fulfill, reject
    else
      false


  @reject: (reason) ->
    new this (fulfill, reject) -> reject reason


  @all: (values) ->
    throw new TypeError 'argument must be an array' unless isArray values
    return @resolve [] if values.length is 0

    new this (fulfill, reject) =>
      pending = values.length
      results = new Array pending

      onFulfill = (i) -> (res) ->
        results[i] = res
        fulfill results if --pending is 0

      for value, i in values
        @resolve value
          .then (onFulfill i), reject


  @allConcurrent: (values) ->
    @all values


  @allSequential: (values) ->
    throw new TypeError 'argument must be an array' unless isArray values
    return @resolve [] if values.length is 0

    new this (fulfill, reject) =>
      count = values.length
      results = []
      chain = @resolve()

      for next in values
        chain = chain
          .then (res) ->
            length = results.push res
            fulfill results if length is count
            next
          ,(reason) ->
            reject reason


  @race: (values) ->
    throw new TypeError 'argument must be an array' unless isArray values
    return @resolve() if values.length is 0

    new this (fulfill, reject) =>
      for value in values
        @resolve value
          .then fulfill, reject
