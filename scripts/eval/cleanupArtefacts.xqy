xquery version "1.0-ml";

xdmp:log('qcsync: Running cleanup script.')
,
let $uris := cts:uri-match('/qcsync/*')
return if (empty($uris)) then (
  xdmp:log('qcsync: No artefacts to remove.'),
  'qcsync: No artefacts to remove.'
) else $uris ! (
  let $msg := 'qcsync: removing artefact [' || . || ']'
  return (
    xdmp:log($msg),
    xdmp:document-delete(.),
    $msg
  )
)
