/*
 * BETTER LOG for MarkLogic
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
 *   - Time parameters if required (otherwise endpoint is auto-detected)
 *     - MINUTES: number of minutes to scan back from the current time
 *     - LAST_TIME: a date string to scan back from
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
var FILTER, FLAGS, FORMAT, LOG_PATH, FOLLOW

const test = () => {
  //const LT = new LogTracker()
  //const res = LT.getLogLines()

  return ' foo bar bum'

}

// entry point
const main = (fmt) => {
  // For testing from qconsole, override the following parameters
  if (xdmp.getRequestPath().toString().startsWith('/qconsole')) {
    // If running from QConsole, use the provided parameters
    FILTER  = 'foo'
    FLAGS   = 'no-eval+no-moz+no-saf+no-chrome'
    FORMAT  = 'json'
    FOLLOW  = true
  }
  const LT = new AccessLogTracker()
  if (LOG_PATH) LT.logPath = LOG_PATH
  LT.processLog(FILTER, FLAGS)
  return LT.output(FORMAT || fmt)
}

/**
 * Base class for scannning log files and tracking position.
 */
class LogTracker {

  constructor() {
    this.logData = [] // Data gather during this transaction are stored here.
    this.serverField = JSON.parse()
    this.hosts = Array.from(xdmp.hosts()).map(xdmp.hostName)
    // Cursors point to last location in all files scans
    // This is the fastest way to process only recent changes
    const sf = getServerField('LOG_CURSORS')
    this.cursors = sf ? JSON.parse(sf) : this.hosts.map(h => ({host: h, logs: []}))
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
    return Array.from(xdmp.hosts()).map(xdmp.hostName).map(host => Array
      .from(filesystemDirectory(this.logPath))
      // search only the current logs
      .filter(x => x.filename.endsWith(this._fileNameEnding) && x.contentLength !== 0)
      .map(x => x.pathname)
      .map(x => {
        return {
          path: x,
          lineNumber: this[host][x],
        }
      })
      .map(x => {
        const lines = filesystemFile(x).toString().split('\n')
        const startFrom = x.lineNumber || lines.length - 200
        this[host][x.path] = lines.length
        return lines.slice(startFrom)
          .map(x => ({host, line: x}))
      }))
      .reduce((p, n) => [...p, ...n], [])
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
}

/**
 * LogTracker class
 */
class AccessLogTracker extends LogTracker {
  static filterFlags = {
     'no-eval': 'POST /v1/eval ',
     'no-moz': 'Mozilla',
     'no-saf': 'Safari',
     'no-chrome': 'Chrom' // Chrome, Chromium, Chrome Mobil
  }
  constructor() {
    super()
    this.type = 'access'
    this.fileNameEnding = `_AccessLog.txt`
  }

  // Loop over all log lines and apply filters and parsing
  processLog(filter, flags = '') {
    this.flags = flags.split('+').filter(x => x)
    this.logData = this.logLines
        .filter(x => x.trim())
        .filter(x => Object.keys(AccessLogTracker.filterFlags).some(flag =>
          x.includes(AccessLogTracker.filterFlags[flag])
        ))
        .map(x => ({
          date: LogTracker.extractDate(x),
          rest: x.split(']').slice(1).join(']').replace(/\"/g, ''),
          source: x.split(' ').shift(),
          user: x.split('-')[1].trim().split(' ').shift().trim() || '-',
          line: x
        }))
        .filter(x => filter ? x.includes(filter) : true)
      .reduce((p, n) => [...p, ...n], [])

    // Record timestamp of last log entry
    if (this.logData.length) {
      const lastTime = this.logData[this.logData.length - 1].date
    }
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

// extract main library functions for neater code
const {
  filesystemDirectory, filesystemFile, platform,
  unquote, logfileScan, getServerField, setServerField
} = xdmp

//main('csv')
test('csv')
