xquery version "1.0-ml";
import module namespace q = "http://marklogic.com/appservices/qconsole/model"  at "/MarkLogic/appservices/qconsole/qconsole-model.xqy";
declare namespace qconsole = "http://marklogic.com/appservices/qconsole";

declare variable $ts as xs:string external;

declare function local:log($msg) { xdmp:log('II qsync: ' || $msg) };
declare function local:run(
  $ts as xs:string
) as xs:string*
{
  local:log('Importing workspaces and queries.'),

  let $uri := '/qcsync/' || $ts || '/_workspace.xml'
  let $import := doc($uri)
  let $queries :=
    for $q in cts:uri-match('/qcsync/' || $ts || '/*')
    where not(contains($q, '_workspace.xml'))
    return $q

  let $matchingWorkspace :=
    let $name := $import//workspace/@name/fn:string()
    return
      for $w in q:get-workspaces(())//workspace
      where $w/name/fn:string() eq $name
      return $w

  return
    if (not(exists($matchingWorkspace)))
    then fn:string-join((
      'WW','No matching workspace found. Please import or rename an existing workspace!'
    ), ',')
    else
      for $q in $queries
      let $pathParts := fn:tokenize($q, '/')
      let $name := $pathParts[fn:last()]
      let $parts := fn:tokenize($name, '\.')
      let $base := $parts[1]
      let $mode :=
        switch ($parts[2])
        case 'xqy' return 'xquery'
        case 'sql' return 'sql'
        case 'spl' return 'sparql'
        case 'ojs' return 'optic'
        case 'js'  return 'javascript'
        default return 'xquery'
      let $haveMatchingTab :=
        for $q in $import//query
        where $q/@name/fn:string() eq $base and $mode eq $q/@mode/fn:string()
        return $q
      return fn:string-join(
        if ($haveMatchingTab)
        then (
          let $id := $matchingWorkspace//queries[name = $base]/id/fn:string()
          let $contents := doc($q)/text()
          let $storedUri := '/queries/' || $id || '.txt'
          return (
            local:log('Updating tab [' || $name || '] with contents from [' || $q || '] in ['|| $storedUri ||']'),
            xdmp:document-insert($storedUri, $contents, <options xmlns="xdmp:document-insert">
                <permissions>{xdmp:document-get-permissions($uri)}</permissions>
                <collections>{
                  <collection>/qcsync</collection>,
                  for $coll in xdmp:document-get-collections($uri)
                  return <collection>{$coll}</collection>
                }</collections>
              </options>
            ),
            ('II', $name, 'Tab contents updated', $storedUri, $q)
          )
        )
        else (
          'WW', $name,
          'Tab not found in workspace: name [' || $base || '] in mode [' || $mode || ']. Please create first and pull.'
        )
      , ',')
};

if (starts-with(xdmp:get-request-url(), '/qconsole'))
then local:run('TEST_WORKSPACE') (: TODO: Add setup :)
else local:run($ts)
