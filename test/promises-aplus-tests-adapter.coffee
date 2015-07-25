'use strict'

Promise = require '../promise'


module.exports =

  resolved: (value) ->
    Promise.resolve value

  rejected: (reason) ->
    Promise.reject reason

  deferred: ->
    resolve = null
    reject = null

    promise = new Promise (res, rej) ->
      resolve = res
      reject = rej

    {promise, resolve, reject}
