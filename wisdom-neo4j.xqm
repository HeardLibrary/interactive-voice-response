(:~
 : This module contains functions for interacting with Neo4J
 : @author Clifford B. Anderson
 :)
module namespace wisdom-neo4j= "http://library.vanderbilt.edu/wisdom/neo4j";

declare variable $wisdom-neo4j:endpoint as xs:string := "http://wisdom:BY0GTs9f73FmLDK3oFdG@wisdom.sb10.stations.graphenedb.com:24789/db/data/transaction/commit";

declare function wisdom-neo4j:http-request($json as xs:string) as document-node()? {
  let $request :=
    <http:request method='post' href="{$wisdom-neo4j:endpoint}">
      <http:body method="text" media-type='application/json'>
        {$json}
      </http:body>
   </http:request>
  let $response:= http:send-request($request)
  let $headers := $response[1]
  let $body := $response[2]
  where $headers/@status/fn:data() = "200"
  return $body
};

declare function wisdom-neo4j:get-node-by-id($id as xs:integer) as element(Response)?
{
 let $json := '{
    "statements" : [ {
      "statement" : "match (a {id:' || $id || '}) return a"
    } ]
  }'
 let $choice := wisdom-neo4j:http-request($json)
 let $options := wisdom-neo4j:get-node-relationships($id)
 let $speech := fn:string-join(($choice//say/string(), $options), " ")
 let $voice := fn:string-join(($choice//voice/string()))
 return wisdom-neo4j:return-twiml($id, $speech, $voice)
};

declare function wisdom-neo4j:traverse-node-by-relationship-id($incoming-node as xs:integer, $digits as xs:integer?) as element(Response)
{
 let $json := '{
   "statements" : [ {
      "statement": "match (a {id:' || $incoming-node || '})-[r {event:' || $digits || '}]->(c) return c.id"
   } ]
 }'
 let $destination-node := wisdom-neo4j:http-request($json)//_[@type="number"]/text()
 return
   if (fn:not(fn:empty($destination-node)))
   then wisdom-neo4j:get-node-by-id($destination-node)
   else wisdom-neo4j:get-node-by-id($incoming-node) (: return user to choices if invalid option selected :)
};

declare function wisdom-neo4j:get-node-relationships($id as xs:integer) as xs:string?
{
  let $json := '{
    "statements" : [ {
       "statement": "match (a {id:' || $id || '})-[r]->(c) return r"
    } ]
  }'
 let $results := wisdom-neo4j:http-request($json)
 let $say :=
   for $obj in $results//row/_
   order by $obj/event/text()
   return $obj/say
 return fn:string-join($say, " ")
};

declare function wisdom-neo4j:return-twiml($id as xs:integer, $speech as xs:string, $voice as xs:string*) as element(Response)
{
  let $play :=
    for $url in $voice
    return <Play>{$url}</Play>
return
  <Response>
    <Gather action="/telephony/traverse/{$id}" method="GET">
        {$play}
        <Say voice="woman" language="en">{$speech}</Say>
    </Gather>
   <Say>We did not receive any input. Goodbye!</Say>
 </Response>
};
