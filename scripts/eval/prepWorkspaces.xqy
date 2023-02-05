xquery version "1.0-ml";
import module namespace qconsole-model = "http://marklogic.com/appservices/qconsole/model"  at "/MarkLogic/appservices/qconsole/qconsole-model.xqy";
declare namespace qconsole = "http://marklogic.com/appservices/qconsole";

xdmp:log('qsync: Exporting workspaces and queries.'),

let $ts := replace(xs:string(current-dateTime()), '[T+.:-]', '')
let $userWorkspaces := cts:search(/qconsole:workspace,
  cts:element-value-query(xs:QName("qconsole:userid"),
  string(xdmp:get-current-userid())))
let $_ := xdmp:log('Found ' || count($userWorkspaces) || ' workspaces for user.')
for $ws in $userWorkspaces
let $name := $ws/qconsole:name/fn:string()
let $wsid := $ws/qconsole:id/data()
let $export := qconsole-model:export-workspace($wsid)
let $wsUri := '/qcsync/exports/' || $ts || '/' || $name || '.workspace.xml'
let $queries := $ws/*:queries/*
let $stem := fn:tokenize($name, '_')[1]
(: keep TFS numbered tabs and "DBA" tabs :)
let $isDbaWorkspace :=  $stem eq 'DBA'
let $startsWithIssueNumber := $stem castable as xs:integer and string-length($stem) gt 4
where not(starts-with($name, 'Workspace')) and ($startsWithIssueNumber or $isDbaWorkspace)
return (
  let $_ := try {
    xdmp:log('qcsync: Writing document [' || $wsUri || ']'),
    xdmp:document-insert($wsUri, $export)
  } catch($e) {
    xdmp:log($e),
    xdmp:log('qcsync: Could not write document [' || $wsUri || ']')
  }
  let $qExports :=
    for $q in $queries
    let $qName := $q/*:name/fn:string()
    let $qid := $q/*:id/fn:string()
    let $mode := $q/*:mode/fn:string()
    let $ext :=
      switch ($mode)
      case 'xquery' return 'xqy'
      case 'sql' return 'sql'
      case 'sparql' return 'spl'
      case 'optic' return 'ojs'
      case 'javascript'  return 'js'
      default return 'xqy'
    let $active := $q/*:active/fn:string()
    let $order := $q/*:taborder/fn:string()
    let $dbName := $q/*:database-name/fn:string()
    where $active eq 'true' and not(starts-with($qName, 'Query'))
    order by $order
    return fn:string-join((
      'Query',fn:string-join(($qName || "." || $ext), '/'),
      $qid, $dbName, $order, $ext, $name, "EOL"
    ), ',')
  return (
    if (count($qExports) gt 0)
    then string-join((
      'Workspace', '.',
      $wsUri, '-','-','-', $name, 'EOL'
    ), ',') else (),
    $qExports
  )
)