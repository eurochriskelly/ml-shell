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
      $permissions ! ('perm:' || xdmp:role-name(./*:role-id/xs:integer(.)) || '=' || ./*:capability/fn:string()),
      '#AMP#'
    ),
    fn:string-join($collections ! ('collection=' || .), '#AMP#'),
    'EOL'
  ),'~')
};

local:main(
   if (fn:starts-with(xdmp:get-request-path(), '/qconsole'))
   then '*frbr*lib*search*xqy'
   else $pattern
)