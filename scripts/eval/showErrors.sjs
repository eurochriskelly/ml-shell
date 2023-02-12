/*
 * Find the last error in the log and prettify
 */

// external vars
var MINUTES
if (!MINUTES) MINUTES = 30

console.log(`Checking for errors in the last [${MINUTES}] minutes`)

const { filesystemDirectory, unquote, logfileScan } = xdmp
const logPath = '/var/opt/MarkLogic/Logs'

const subtractMinutes = (date, minutes) => {
  return new Date(date.getTime() - minutes * 60000)
}

const errors = Array
  .from(filesystemDirectory(`${logPath}`))
  // search only the current logs
  .filter(x => x.filename.endsWith('_ErrorLog.txt') && x.contentLength !== 0)
  .map(x => x.pathname)
  .map(x => logfileScan(x, "<error:", null, xs.dateTime(subtractMinutes(new Date(), MINUTES))))
  .map(x => x.toString().substring(30))
  .join('\n')


let result = ''
try {
  if (errors.length) {
    const xml = unquote(`<error>${errors}</error>`)
    result = xml.xpath('//*:error')
  } else {
    result = errors
  }
} catch (e) {
  console.log(e)
  result = e
}

result
