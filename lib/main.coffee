VunitRunner = require './vunit-runner'

module.exports =

  activate: (state) ->

  deactivate: ->

  provideTestRunner: ->
    return {
      runner: VunitRunner
      key: "vunit"
    }
