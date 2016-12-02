{Emitter} = require 'event-kit'
spawn = require('child_process').spawn
spawnSync = require('child_process').spawnSync
path = require('path')

class VunitRunner

  name: "Vunit Runner"
  testLineRegex: /(.+?):(\d+):([\s\w]+\.[\s\w]+\.[\s\w]+)/
  startTestRegex: /Starting ([\s\w]+\.[\s\w]+\.[\s\w]+)/
  stopTestRegex: /(pass|fail) \(.+?\) ([\s\w]+\.[\s\w]+\.[\s\w]+) \((\d+\.\d+) \w+\)/

  constructor: (@options) ->
    @emitter = new Emitter()

  destroy: ->
    @emitter.dispose()

  onTestStart: (callback) ->
    @emitter.on 'test-start', callback

  onTestEnd: (callback) ->
    @emitter.on 'test-end', callback

  getTests: ->
    tests = []
    temp = ""

    pythonInterpreter = @options.pythonInterpreter or "python"
    proc = spawn(
      pythonInterpreter,[@options.file,"-l","-v"],{cwd: @options.projectPath}
    )

    return new Promise((resolve, reject) =>
      proc.on 'error', (err) ->
        atom.notifications.addError(
          'Failed to get vunit test list.', {details: proc.error.toString()}
        )
        reject(err)

      proc.on 'close', ->
        resolve(tests)

      proc.stdout.on 'data', (data) =>
        splitted = data.toString().split(/\r\n|\r|\n/g)
        lines = splitted.splice(0,splitted.length - 1)
        lines[0] = temp + lines[0]
        temp = splitted[splitted.length - 1]
        for line in lines
          if ((match = @testLineRegex.exec(line)) isnt null)
            split = match[3].split(".")
            tests.push({
              testIdentifier: match[3]
              packageNames: [split[0]]
              classname: split[1]
              testname: split[2]
              filename: match[1]
              line: match[2]
              column:1
            })
    )

  runTests: (tests) ->
    return new Promise((resolve, reject) =>
      asyncRun = () =>
        i = 0
        execTest = () =>
          @runTest(tests[i].testIdentifier).then( () ->
            i++
            if i < tests.length
              process.nextTick(execTest)
            else
              resolve()
          , (err)->
            reject(err)
          )
        if i < tests.length
          process.nextTick(execTest)
        else
          resolve()
      asyncRun()
    )

  runAllTests: ->
    return @runTest("")

  runTest: (testIdentifier) ->
    pythonInterpreter = @options.pythonInterpreter or 'python'
    args = [@options.file]
    if testIdentifier isnt ""
      args.push(testIdentifier)

    #run tests
    proc = spawn(
      pythonInterpreter,args,{cwd: @options.projectPath}
    )
    temp = ""
    log = []

    return new Promise((resolve, reject) =>
      proc.on 'error', (err) ->
        atom.notifications.addError(
          'Failed to get vunit test list.', {details: err.toString()}
        )
        reject(err)

      proc.on 'close', (err) ->
        resolve()

      proc.stderr.on 'data', (data) ->
        console.log data.toString()

      proc.stdout.on 'data', (data) =>
        splitted = data.toString().split(/\r\n|\r|\n/g)
        lines = splitted.splice(0,splitted.length - 1)
        lines[0] = temp + lines[0]
        temp = splitted[splitted.length - 1]
        for line in lines
          if ((match = @startTestRegex.exec(line)) isnt null)
            split = match[1].split(".")
            @emitter.emit 'test-start', {
              testIdentifier: match[2]
              packageNames: [split[0]]
              classname: split[1]
              testname: split[2]
            }
          else if ((match = @stopTestRegex.exec(line)) isnt null)
            split = match[2].split(".")
            @emitter.emit 'test-end', {
              testIdentifier: match[2]
              packageNames: [split[0]]
              classname: split[1]
              testname: split[2]
              hasFailed: match[1] == "fail"
              hasError: false
              duration: parseFloat(match[3])
              log: log
              stacktrace: []
            }
            log = []
          else
            log.push(line)
      )


module.exports = VunitRunner
