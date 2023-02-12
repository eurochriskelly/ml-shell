/*
 * Find the last error in the log and prettify
 */

// external vars
var MINUTES, PATTERN, DAY, TIME, INITIALIZE

// functions
const { filesystemDirectory, unquote, logfileScan } = xdmp

if (INITIALIZE && INITIALIZE === '1') {
  console.log(`Starting to follow logs...`)
} else {
  let useTime

  // console.log(`Checking for errors in the last [${MINUTES}] minutes.: [${DAY}T${TIME}]`)
  const subtractMinutes = (date, minutes) => new Date(date.getTime() - minutes * 60000)
  if (DAY && DAY.startsWith('20')) {
    const d = new Date(`${DAY}T${TIME}`)
    const t = new Date(d.getTime() + 3) // add 1 second to make sure we get the last line (if it's not a full minute
    useTime = xs.dateTime(t)
  } else {
    if (!MINUTES) MINUTES = 1
    useTime = xs.dateTime(subtractMinutes(new Date(), MINUTES))
  }

  if (!PATTERN) PATTERN = null

  const logPath = '/var/opt/MarkLogic/Logs'
  const lines = Array
    .from(filesystemDirectory(`${logPath}`))
    // search only the current logs
    .filter(x => x.filename.endsWith('_ErrorLog.txt') && x.contentLength !== 0)
    .map(x => x.pathname)
    .map(x => logfileScan(x, PATTERN, null, useTime))
    .map(x => x.toString())
    .map(x => x.trim())
    .join('\n')

  lines
}

