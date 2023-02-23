/*
 * LOG STREAMER for MarkLogic
 *
 * AUTHOR: Chris Kelly, MarkLogic Corporation
 * VERSION: 0.1
 * LICENSE: MIT
 * NOTES: This script can be run direct from Query Console but is intended to be
 *        used by simply looping using client (e.g. bash, python, node, etc.)
 *
 * DESCRIPTION:
 * Find the last error in the log and prettify
 * - To ensure proper tailing, this script makes (light) use of server
 *   fields to track the time of the most recently read log entry.
 *
 * OPTIONS:
 * - The script can be run with the following parameters:
 *   - FILTER: a string to filter the log entries by
 *   - FLAGS: a string of flags separated by '+'
 *     - no-eval: filter out noisy eval requests
 *   - HOSTS: a comma separated list of hosts to scan (if ommited it will
 *     scan all hosts in the cluster with the overhead of finding them first)
 *
 * TODO:
 * - Save and share gist
 * - Add server-side timing recommendations
 * - Integrate error log in same view
 * - Extract cluster nodes and splice those logs in with source column
 * - Skip over server stored number of lines (faster than parsing)
 * - Sort results if there are multiple
 */

// Optional externally provided parameters
var FILTER, FLAGS, FORMAT, LOG_PATH, FOLLOW, TYPE, VERBOSE, USAGE

const DD = msg => VERBOSE && xdmp.log(`DD: ${msg}`)
if (USAGE || USAGE == '') {
  [
    'Usage: recentAccess.sjs [options]',
    'Options:',
    '',
    '  FILTER: only show log entries that contain this string',
    '  FLAGS: a string of flags separated by "+"',
    '    no-eval: filter out noisy eval requests',
    '    no-moz: filter out noisy Mozilla requests',
    '    no-saf: filter out noisy Safari requests',
    '    no-chrome: filter out noisy Chrome requests',
    '  FORMAT: output format (json, csv, or text)',
    '  LOG_PATH: path to log files (default: /var/opt/MarkLogic/Logs)',
    '  FOLLOW: follow the log file (default: true)',
    '  TYPE: type of log to scan (access or error)',
    '  VERBOSE: show verbose information',
    '  USAGE: show this help message',
    '',
    'Examples:',
    '  mlsh eval -s recentAccess.sjs -v FILTER=foo,FLAGS=no-eval+no-moz+no-saf+no-chrome,FORMAT=json,LOG_PATH=/var/opt/MarkLogic/Logs,FOLLOW=true,TYPE=error,VERBOSE=true,USAGE=false',

  ].join('\n')
} else {

  // entry point
  const main = (fmt) => {
    DD('main function')
    let LT
    if (xdmp.getRequestPath().toString().startsWith('/qconsole')) {
      // If running from QConsole, use the provided parameters
      FILTER = 'foo'
      FLAGS = 'no-eval+no-moz+no-saf+no-chrome'
      FORMAT = 'json'
      FOLLOW = true
    }
    TYPE = TYPE || 'error'

    DD('External variables:')
    const extVars = { FILTER, FLAGS, FORMAT, LOG_PATH, FOLLOW, TYPE, VERBOSE, USAGE }
    Object.keys(extVars).forEach(key => {
      if (extVars[key]) {
        DD(`${key}: ${extVars[key]}`)
      }
    })
    switch (TYPE) {
      case 'access':
        LT = new AccessLogTracker()
        if (LOG_PATH) LT.logPath = LOG_PATH
        LT.processLog(FILTER, FLAGS)
        break

      case 'error':
        LT = new ErrorLogTracker()
        if (LOG_PATH) LT.logPath = LOG_PATH
        LT.processLog(FILTER, FLAGS)
        LT._fileNameEnding = '_ErrorLog.txt'
        break
    }
    return [
      LT.output(FORMAT || fmt),
      VERBOSE && '===== VERBOSE INFORMATION =====',
      VERBOSE && `Prior cursors: ${JSON.stringify(LT.initialCursors)}`,
      VERBOSE && `Data length: ${LT.logLength}, File: ${LT.logFile}`,
      VERBOSE && `Log data length: ${LT.logData.length}`,
      VERBOSE && `Time elapsed [${xdmp.elapsedTime()}]`,
    ].join('\n')
  }

  /**
   * Base class for scannning log files and tracking position.
   */
  class LogTracker {

    constructor() {
      DD('LogTracker constructor')
      this.logData = [] // Data gather during this transaction are stored here.
      this.hosts = Array.from(xdmp.hosts()).map(x => xdmp.hostName(x).toString())
      // Cursors point to last location in all files scans
      // This is the fastest way to process only recent changes
      const sf = getServerField('LOG_CURSORS').toString().trim()
      this.cursors = sf
        ? JSON.parse(sf)
        : this.hosts.map(h => ({ host: h.toString(), logs: {} }))
      this.initialCursors = JSON.parse(JSON.stringify(this.cursors))
    }

    set logPath(path) { this._logPath = path }

    // Get the log path. Use sensible defaults if no override is provided
    get logPath() {
      return this._logPath || platform() === 'winnt'
        ? '/Program Files/MarkLogic/Data/Logs'
        : '/var/opt/MarkLogic/Logs'
    }

    set fileNameEnding(str) { this._fileNameEnding = str }

    // Get the lines of logs from where we last left off
    get logLines() {
      const lines = this.hosts
        .map(host => Array
          .from(filesystemDirectory(this.logPath))
          .filter(x => x.filename.endsWith(this._fileNameEnding) && x.contentLength !== 0)
          .map(x => x.pathname)
          .map(path => ({
            path, host, cursorLocation: this.cursors
              .filter(c => c.host === host)
              .map(c => {
                return c.logs[path] || -500
              })
          }))
        )
        .reduce((p, n) => [...p, ...n], [])
        .map(x => {
          const { host, path, cursorLocation } = x
          let data = filesystemFile(path).toString()
          this.logLength = data.length
          this.logFile = path
          this.logSize = `Path: ${path} - Size: ${data.length} - Cursor: ${cursorLocation}`
          this.cursors
            .filter(x => x.host === host)
            .forEach(x => x.logs[path] = data.length)
          data = data.substr(cursorLocation)
          this.raw = data
          const lines = data.split('\n')
          return lines.map(x => ({ host, path, line: x }))
        })
        .reduce((p, n) => [...p, ...n], [])
      setServerField('LOG_CURSORS', JSON.stringify(this.cursors))
      return lines
    }
  }

  /**
   * LogTracker class
   */
  class AccessLogTracker extends LogTracker {

    constructor() {
      DD('AccessLogTracker constructor')
      super()
      this.filterFlags = {
        'no-eval': 'POST /v1/eval ',
        'no-moz': 'Mozilla',
        'no-saf': 'Safari',
        'no-chrome': 'Chrom' // Chrome, Chromium, Chrome Mobil
      }
      this.type = 'access'
      this.fileNameEnding = `_AccessLog.txt`
    }

    // Loop over all log lines and apply filters and parsing
    processLog(filter, flags = '') {
      this.flags = flags.split('+').filter(x => x)
      this.logData = this.logLines
        .filter(x => x.line.trim())
        .filter(x => Object.keys(this.filterFlags).some(flag =>
          x.line.includes(this.filterFlags[flag])
        ))
        .map(x => {
          const { line } = x
          return {
            ...x,
            date: AccessLogTracker.extractDate(line),
            rest: line.split(']').slice(1).join(']').replace(/\"/g, ''),
            source: line.split(' ').shift(),
            user: line.split('-')[1].trim().split(' ').shift().trim() || '-',
          }
        })
        .filter(x => filter ? x.line.includes(filter) : true)
        .sort((a, b) => a.date > b.date ? 1 : -1)
      // .reduce((p, n) => [...p, ...n], [])
    }

    // Extract the date as formated by the access log
    // e.g [01/Jan/2019:00:00:00 +0000]
    // ISO dates are used in other logs
    static extractDate(str) {
      let date = str.match(/\[(.*?)\]/)[1]
      let res = date.match(/([\d]{2})\/([A-Za-z]{3})\/([\d]{4}):([\d]{2}:[\d]{2}:[\d]{2})/)
      let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      let isoDate = `${res[3]}-${`00${months.indexOf(res[2]) + 1}`.slice(-2)}-${res[1]}T${res[4]}.000Z`
      return isoDate
    }

    // Output the log lines
    output(format = 'csv') {
      switch (format) {
        case 'csv':
          return this.logData
            .map(x => `${x.date},${x.user},${x.source},${x.rest}`)
            .join('\n')
        case 'json':
          return JSON.stringify(this.logData)
        // prettified json
        case 'jsonpp':
          return JSON.stringify(this.logData, null, 2)
        case 'text':
        case 'txt':
          return this.logData
            .map(x => `${x.date} ${x.user} ${x.source} ${x.rest}`)
            .join('\n')

        default:
          return this.logData
      }
    }
  }

  /**
   * Error log tracker class
   * @extends LogTracker
   * @param {string} filter - Filter string
   * @param {string} flags - Flags to apply to the filter
   * @param {string} format - Output format
   *
   * @example
   * const tracker = new ErrorLogTracker()
   *
   * // Set the log path  (optional)
   * tracker.logPath = '/var/opt/MarkLogic/Logs'
   *
   * // Process the logs
   * tracker.processLog('error')
   *
   * // Output the logs
   *
   * // Output as csv
   * tracker.output('csv')
   */
  class ErrorLogTracker extends LogTracker {
    constructor() {
      DD('ErrorLogTracker constructor')
      super()
      this.filterFlags = {
        'no-chrome': 'Chrom'
      }
      this.type = 'error'
      this.fileNameEnding = `ErrorLog.txt`
    }

    // Loop over all log lines and apply filters and parsing
    processLog(filter, flags = '') {
      this.flags = flags.split('+').filter(x => x)
      this.logData = this.logLines
        .filter(x => x.line.trim())
        .filter(x => Object.keys(this.filterFlags).some(flag =>
          !x.line.includes(this.filterFlags[flag])
        ))
        .map(x => {
          const { line } = x
          return {
            ...x,
            date: ErrorLogTracker.extractDate(line),
          }
        })
        .filter(x => filter ? x.line.includes(filter) : true)
        .sort((a, b) => a.date > b.date ? 1 : -1)
    }

    // Extract the date as formated by the access log
    // e.g take from the start of the line
    // ISO dates are used in other logs
    static extractDate(str) {
      return str.substring(0, 25).split(' ').slice(0, 2).join('T')
    }

    // Output the log lines
    output(format = 'csv') {
      switch (format) {
        case 'csv':
          return this.logData
            .map(x => `${x.date},${x.line}`)
            .join('\n')
        case 'json':
          return JSON.stringify(this.logData)
        // prettified json
        case 'jsonpp':
          return JSON.stringify(this.logData, null, 2)
        case 'text':
        case 'txt':
          return this.logData
            .map(x => `${x.date} ${x.line}`)
            .join('\n')
        default:
          return this.logData
      }
    }
  }

  // extract main library functions for neater code
  const {
    filesystemDirectory, filesystemFile, platform, getServerField, setServerField
  } = xdmp
  main('csv')
}
