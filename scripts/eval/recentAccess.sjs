/*
 * Find the last error in the log and prettify
 * - To ensure proper tailing, this script makes (light) use of server
 *   fields to track the time of the most recently read log entry.
 *
 * - The script can be run with the following parameters:
 *   - Time parameters if required (otherwise endpoint is auto-detected)
 *     - MINUTES: number of minutes to scan back from the current time
 *     - LAST_TIME: a date string to scan back from
 *   - FILTER: a string to filter the log entries by
 *   - FLAGS: a string of flags separated by '+'
 *     - no-eval: filter out noisy eval requests
 *
 * TODO:
 * - Save and share gist
 * - Add server-side timing recommendations
 * - Integrate error log in same view
 * - Extract cluster nodes and splice those logs in with source column
 */

// Optional externally provided parameters
var FILTER, FLAGS, FORMAT, MINUTES, LAST_TIME, LOG_PATH

// entry point
const main = (fmt) => {
  const LT = new LogTracker(LAST_TIME, MINUTES)
  if (LOG_PATH) LT.logPath = LOG_PATH
  LT.processLog(FILTER, FLAGS)
  return LT.output(FORMAT || fmt)
}

/**
 * LogTracker class
 */
class LogTracker {

  constructor(lastTime, minutesAgo) {
    this.lastTimeServerField = 'ACCESSLOG_LAST_TIME'
    this.lastTime = this.getLastTime(lastTime, minutesAgo)
    this.logLines = []
  }

  // Loop over all log lines and apply filters and parsing
  processLog(filter, flags = '') {
    this.flags = flags.split('+').filter(x => x)
    this.logLines = Array
      .from(filesystemDirectory(this.logPath))
      // search only the current logs
      .filter(x => x.filename.endsWith(`_AccessLog.txt`) && x.contentLength !== 0)
      .map(x => x.pathname)
      .map(x => filesystemFile(x).toString().split('\n')
        .filter(x => {
          if (flags.includes('no-eval')) return !x.includes('POST /v1/eval ')
          if (flags.includes('no-moz')) return !x.includes('Mozilla')
          if (flags.includes('no-saf')) return !x.includes('Safari')
          if (flags.includes('no-chrome')) return !x.includes('Chrom') // Chrome, Chromium, Chrome Mobile
          return true
        })
        .filter(x => x)
        .map(x => ({
          date: LogTracker.extractDate(x),
          rest: x.split(']').slice(1).join(']').replace(/\"/g, ''),
          source: x.split(' ').shift(),
          user: x.split('-')[1].trim().split(' ').shift().trim() || '-',
          line: x
        }))
        .filter(x => x.date > this.lastTime)
        .filter(x => filter ? x.includes(filter) : true)
      )
      .reduce((p, n) => [...p, ...n], [])

    // Record timestamp of last log entry
    if (this.logLines.length) {
      const lastTime = this.logLines[this.logLines.length - 1].date
      setServerField(this.lastTimeServerField, lastTime)
    }
  }

  // Get the last time, preferrably using the server field to enable simple
  // tailing for client
  getLastTime(lastTime, minutesAgo = 5) {
    const addMinutes = (date, minutes) => new Date(date.getTime() + (minutes * 60000))
    if (!lastTime) {
      // At worst it will scan the entire log for current day
      let storedTime = getServerField(this.lastTimeServerField)
      let lastTime = storedTime ? new Date(storedTime) : new Date()
      const res = addMinutes(lastTime, storedTime ? 0.0001 : -minutesAgo).toISOString()
      return res
    }
    return lastTime
  }

  set logPath(path) {
    this._logPath = path
  }
  // Get the log path. Use sensible defaults if no override is provided
  get logPath() {
    return this._logPath || platform() === 'winnt'
      ? '/Program Files/MarkLogic/Data/Logs'
      : '/var/opt/MarkLogic/Logs'
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
        return this.logLines
          .map(x => `${x.date},${x.user},${x.source},${x.rest}`)
          .join('\n')
      case 'json':
        return JSON.stringify(this.logLines)
      // prettified json
      case 'jsonpp':
        return JSON.stringify(this.logLines, null, 2)
      case 'text':
      case 'txt':
        return this.logLines
          .map(x => `${x.date} ${x.user} ${x.source} ${x.rest}`)
          .join('\n')

      default:
        return this.logLines
    }
  }
}

// extract main library functions for neater code
const {
  filesystemDirectory, filesystemFile, platform,
  unquote, logfileScan, getServerField, setServerField
} = xdmp

main('csv')
