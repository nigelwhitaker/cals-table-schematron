<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright 2011, 2013 DeltaXML Ltd.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.  -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema" 
                xmlns:dxa="http://www.deltaxml.com/ns/non-namespaced-attribute"
                xmlns:cals="http://www.deltaxml.com/ns/cals-table"
                xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                version="2.0" exclude-result-prefixes="#all">
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p>This stylesheet defines functions related to CALS tables.</xd:p>
      <xd:p>It is intended for inclusion by other filters and schematron that wish to make use of the functions.</xd:p>
    </xd:desc>
  </xd:doc>

  
  <xd:doc>
    <xd:desc>
      <xd:p>Provides the distance between 2 rows (in the same table).</xd:p>
      <xd:p>The same rows are distance 0.  Adjacent are distance 1 etc... 
            For very long tables this is inefficient.  Performance could perhaps
            be improved by keying (eg:  keying rows by position) or using <![CDATA[<<]]> or >> operators</xd:p>
    </xd:desc>
    <xd:param name="r1">One of the rows</xd:param>
    <xd:param name="r2">and another</xd:param>
    <xd:return>the distance bewteen the rows specified as params</xd:return>
  </xd:doc>
  <xsl:function name="cals:row-distance2" as="xs:integer">
    <xsl:param name="r1" as="element()"/>
    <xsl:param name="r2" as="element()"/>
    <xsl:variable name="r1pos" as="xs:integer"
      select="count($r1/preceding-sibling::*:row) +1"/>
    <xsl:variable name="r2pos" as="xs:integer"
      select="count($r2/preceding-sibling::*:row) +1"/>
    <xsl:sequence select="abs($r1pos - $r2pos)"/>
  </xsl:function>

  <xd:doc>
    <xd:desc>
      <xd:p>Name dereferencing for cals attributes.</xd:p>
      <xd:p>Because you can't get from an attribute in XPath to its parent element, need two params</xd:p>
    </xd:desc>
    <xd:param name="elem">A table cell (entry/entrytbl) or a spanspec</xd:param>
    <xd:param name="attr">a column name referencing attribute in the above elem</xd:param>
    <xd:return>the colspec that the name refers to, or empty if does not exist</xd:return>
  </xd:doc>
  <xsl:function name="cals:lookup" as="element()?">
    <!-- returns the referenced entity or none if the element cant be found -->
    <!-- doesnt check for duplicate results, possibly another constraint/phase -->
    <xsl:param name="elem" as="element()"/> <!-- an entry, entrytbl or spanspec -->
    <xsl:param name="attr" as="attribute()"/> <!-- an @colname, @namest, @nameend or @spanname in the above elem -->
    <xsl:choose>
      <xsl:when test="$elem/parent::*:row/parent::*[self::*:thead or self::*:tfoot]/*:colspec">
        <!-- if an entry is in the context of a head/foot and that head/foot contains at least
          one colspec then all references are to that context, not the outer name space -->
        <xsl:sequence select="($elem/../../*:colspec[@colname=$attr])[1]"/>
      </xsl:when>
      <!-- if the attr is colname, namest or nameend, it is referring to a colspec 
        the relevant colspec is in the nearest tgroup or entrytbl -->
      <xsl:when test="name($attr) = ('colname', 'namest', 'nameend')">
        <xsl:sequence select="($elem/ancestor::*[self::*:tgroup or self::*:entrytbl][1]/*:colspec[@colname=$attr])[1]"/>
      </xsl:when>
      <!-- if the attr is spanname, it is referring to a spanspec 
        the relevant spanspec is in the nearest tgroup or entrytbl -->
      <xsl:when test="name($attr) eq 'spanname'">
        <xsl:sequence select="($elem/ancestor::*[self::*:tgroup or self::*:entrytbl][1]/*:spanspec[@spanname=$attr])[1]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="error(QName('deltaxml', 'e2'), concat('referencing error for ', name($attr)))"/>
      </xsl:otherwise>
    </xsl:choose> 
  </xsl:function>
  
  <xd:doc>
    <xd:desc>
      <xd:p>Determines the column position for a colspec (1 based from left)</xd:p>
    </xd:desc>
    <xd:param name="col">A colspec</xd:param>
    <xd:return>It's position or index</xd:return>
  </xd:doc>
  <xsl:function name="cals:colnum" as="xs:integer">
    <xsl:param name="col" as="element()"/> <!-- element is a colspec -->
    <xsl:sequence select="if (exists($col/@colnum)) then $col/@colnum else 
      if ($col/preceding-sibling::*:colspec) then cals:colnum($col/preceding-sibling::*:colspec[1]) + 1 else 1"/>
  </xsl:function>
  
  <xd:doc>
    <xd:desc>
      <xd:p>Gives the columns occupied by an entry in terms of a sequence of integers corresponding to column positions</xd:p>
    </xd:desc>
    <xd:param name="entry">A table entry or entrytbl</xd:param>
    <xd:return>The occupied column(s) as a sequence of one or more integers</xd:return>
  </xd:doc>
  <xsl:function name="cals:entry-to-columns" as="xs:integer+">
    <xsl:param name="entry" as="element()"/> <!-- *:entry or *:entrytbl -->
    <xsl:choose>
      <xsl:when test="$entry/@spanname">
        <!-- look up span -->  <!-- cant be in a thead or tfoot -->
        <xsl:variable name="span" as="element()" select="cals:lookup($entry, $entry/@spanname)"/>
        <xsl:variable name="fromCol" as="element()" select="cals:lookup($span, $span/@namest)"/>
        <xsl:variable name="toCol" as="element()" select="cals:lookup($span, $span/@nameend)"/>
        <xsl:sequence select="(cals:colnum($fromCol) to cals:colnum($toCol))"/>
      </xsl:when>
      <xsl:when test="$entry/@namest and $entry/@nameend">
        <xsl:variable name="fromCol" as="element()" select="cals:lookup($entry, $entry/@namest)"/>
        <xsl:variable name="toCol" as="element()" select="cals:lookup($entry, $entry/@nameend)"/>
        <xsl:sequence select="(cals:colnum($fromCol) to cals:colnum($toCol))"/>
      </xsl:when>
      <xsl:when test="$entry/@namest">
        <xsl:sequence select="(cals:colnum(cals:lookup($entry, $entry/@namest)))"/>
      </xsl:when>
      <xsl:when test="$entry/@colname">
        <xsl:sequence select="(cals:colnum(cals:lookup($entry, $entry/@colname)))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="cals:get-default-col-pos($entry)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  
  <xd:doc>
    <xd:desc>
      <xd:p>Determines where a table would be placed by default, ie when the @colname or @spanname
        attributes are not present or if they are ignored.  The default position depends on the
        position of the previous entry and also takes into account spanning or @morerows
        from columns in rows above.</xd:p>
    </xd:desc>
    <xd:param name="entry">A table cell</xd:param>
    <xd:return>its default position</xd:return>
  </xd:doc>
  <xsl:function name="cals:get-default-col-pos" as="xs:integer">
    <xsl:param name="entry" as="element()"/> <!-- *:entry or *:entrytbl -->
    <!-- implict resolution -->
    <!-- what is col pos of last entry, add any morerows if they are adjacent, add 1-->
    <xsl:variable name="preceedingPos" as="xs:integer" 
      select="if ($entry/preceding-sibling::*[self::*:entry or self::*:entrytbl])
      then max(cals:entry-to-columns($entry/preceding-sibling::*[self::*:entry or self::*:entrytbl][1]))
      else xs:integer(0)"/>
    <xsl:variable name="candidatePos" as="xs:integer"
      select="$preceedingPos + 1"/>
    <xsl:variable name="overlaps" as="xs:integer*"
      select="cals:overlap2($entry/ancestor::*:row[1])"/>
    <xsl:variable name="cols" as="xs:integer" select="$entry/ancestor::*[@cols][1]/@cols"/>
    <xsl:variable name="nonOverlaps" as="xs:integer*"
      select="for $i in 1 to $cols return if ($i = $overlaps) then () else $i"/>
    <!-- nonOverlaps are the inverse of the overlaps - ie rows from above which do not have 
       a presence in the current row so if our candidate position is 'clear' we will use it, otherwise the next available position -->
    <xsl:variable name="nonOverlapsGECandidate" as="xs:integer*" select="$nonOverlaps[. ge $candidatePos]"/>
    <!-- if all the remaining possible positions are overlapped we're stuck - use cols+1 which is illegal as
          the result to pass out so that the calling code can report an error -->
    <xsl:sequence select="if (count($nonOverlapsGECandidate) ge 1) then min($nonOverlapsGECandidate) else $cols+1"/>
  </xsl:function>

  <xd:doc>
    <xd:desc>
      <xd:p>Describes how a table row is spanned from above.</xd:p>
      <xd:p>This result is a set of columns which are overlapped from above in the row specified as
            an argument.  The 'set' is really a sequence and may be out of order, eg:  (3, 2).</xd:p>
      <xd:p>There may not be a one to one correspondence between the columns and @morerows attributes
        as the columns that descend with @morerows may also be wide columns using horizontal
        spanning (@spanname, @namest, @nameend etc).</xd:p>
    </xd:desc>
    <xd:param name="row">A table row</xd:param>
    <xd:return>A sequence of integers specifying which columns are spanned or 'infringed' from above</xd:return>
  </xd:doc>
  <xsl:function name="cals:overlap2" as="xs:integer*">
    <xsl:param name="row" as="element()"/> 
    <xsl:sequence 
      select="for $r in $row/preceding-sibling::*:row,  
                  $e in $r/*[@morerows] return
                   if (xs:integer($e/@morerows) ge cals:row-distance2($r, $row)) then
                     cals:entry-to-columns($e)
                   else
                     ()"/>
  </xsl:function>
</xsl:stylesheet>
