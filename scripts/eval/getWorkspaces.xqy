xquery version "1.0-ml";
import module namespace qconsole-model = "http://marklogic.com/appservices/qconsole/model"  at "/MarkLogic/appservices/qconsole/qconsole-model.xqy";
declare namespace qconsole = "http://marklogic.com/appservices/qconsole";


let $userWorkspaces := cts:search(/qconsole:workspace,
  cts:element-value-query(xs:QName("qconsole:userid"),
  string(xdmp:get-current-userid())))
return fn:distinct-values(
  for $ws in $userWorkspaces
  let $name := $ws/qconsole:name/fn:string()
  (: Where the name does not start with "Workspace" :)
  where fn:not(fn:starts-with($name, 'Workspace'))
    and not(contains($name, ' '))
  order by $name
  return $name || ',' || 'EOL')
