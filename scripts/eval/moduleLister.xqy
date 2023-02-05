xquery version "1.0-ml";

declare variable $pattern as xs:string external;

declare function local:main(
  $pattern as xs:string
)
{
  for $m in cts:uri-match($pattern)[1 to 50]
  let $permissions := xdmp:document-get-permissions($m)
  let $collections := xdmp:document-get-collections($m)
  return fn:string-join((
    $m,
    fn:replace($m, '/', '%'),
    fn:string-join(
      $permissions ! (./*:capability/fn:string() || ':' || ./*:role-id/fn:string()),
      ','),
    fn:string-join($collections, ','),
    'EOL'
    ), '~')
};

local:main(
   if (fn:starts-with(xdmp:get-request-path(), '/qconsole'))
   then '/*/frbr/*style*create*.xsl'
   else $pattern
)