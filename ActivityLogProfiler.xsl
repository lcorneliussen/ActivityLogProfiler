<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:msxsl="urn:schemas-microsoft-com:xslt">
  <xsl:output method="html"  encoding="utf-16"/>
  
  <!-- 
  Created by lcorneliussen, based on original ActivityLog.xsl
  
  How to use with GIT (2):
    1) Open Commandwindow in '%AppData%\Roaming\Microsoft\VisualStudio\10.0'
    2) Run 'git clone https://github.com/lcorneliussen/ActivityLogProfiler'
    3) Start Visual Studio with '/Log' switch
    4) Run 'deploy.cmd' (will override '../ActivityLog.xsl'
    5) Open '%AppData%\Roaming\Microsoft\VisualStudio\10.0\ActivityLog.xml' in Internet Explorer
    
  Now you only have to repeat 3) and 4) to produce new logs, as Visual Studio will 
  recreate both ActivityLog.xml and ActivityLog.xsl each time it is started with '/Log'.
  
  How to use without GIT (1):
    1) Start Visual Studio with '/Log' switch
    2) Replace '%AppData%\Roaming\Microsoft\VisualStudio\10.0\ActivityProfiler.xsl' with this one
    3) Open '%AppData%\Roaming\Microsoft\VisualStudio\10.0\ActivityLog.xml' in Internet Explorer

  -->

  <!-- nothing should take more than 500 ms :-) -->
  <xsl:variable name="thresholdTime" select="number(0.2)"/>
  
  <!-- make a red line per "tick" -->
  <xsl:variable name="visualTickEveryXSeconds" select="number(1)"/>

  <xsl:variable name="firstEntrySeconds">
    <xsl:call-template name="seconds">
      <xsl:with-param name="time" select="/activity/entry[1]/time"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="lastEntrySeconds">
    <xsl:call-template name="seconds">
      <xsl:with-param name="time" select="/activity/entry[last()]/time"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="_annotatedActivity">
    <annotatedActivity>
      <xsl:apply-templates select="/activity/entry" mode="annotate"/>
    </annotatedActivity>
  </xsl:variable>

  <xsl:variable name="annotatedActivity" select="msxsl:node-set($_annotatedActivity)/annotatedActivity" />

  <xsl:template match="entry" mode="annotate">

    <xsl:copy>
      <xsl:variable name="isBeginPackageLoad" select="starts-with(description, 'Begin package load ')"/>
      <xsl:variable name="isEndPackageLoad" select="starts-with(description, 'End package load ')"/>

      <xsl:variable name="isEnteringFunction" select="starts-with(description, 'Entering function ')"/>
      <xsl:variable name="isLeavingFunction" select="starts-with(description, 'Leaving function ')"/>

      <xsl:if test="$isLeavingFunction">
        <xsl:attribute name="type">leaving-typelib-call</xsl:attribute>
      </xsl:if>

      <xsl:if test="$isEndPackageLoad">
        <xsl:attribute name="type">package-loaded</xsl:attribute>
      </xsl:if>

      <xsl:variable name="isBeginRecord" select="$isEnteringFunction"/> 

      <xsl:variable name="previousRecordNumer" select="number(record)-1"/>
      <xsl:variable name="previousRecord" select="/activity/entry[record=$previousRecordNumer]"/>

      <xsl:variable name="correlatingBeginDescription1" select="concat('Begin', substring(description, 4))"/>
      <xsl:variable name="correlatingBeginDescription2" select="concat('Entering', substring(description, 8))"/>
      <xsl:variable name="correlatingBeginRecord" select="(preceding-sibling::entry[description=$correlatingBeginDescription1 or description=$correlatingBeginDescription2])[last()]"/>

      <xsl:if test="$correlatingBeginRecord/record">
        <xsl:attribute name="correlatingBeginRecordNumber"><xsl:value-of select="$correlatingBeginRecord/record"/></xsl:attribute>
      </xsl:if>

      <xsl:variable name="refPointTime">
        <xsl:choose>
          <xsl:when test="$correlatingBeginRecord">
            <xsl:value-of select="$correlatingBeginRecord/time"/>
          </xsl:when>
          <xsl:when test="$previousRecord">
            <xsl:value-of select="$previousRecord/time"/>
          </xsl:when>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="previousRecordSeconds">
        <xsl:call-template name="seconds">
          <xsl:with-param name="time" select="$previousRecord/time"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="refPointSeconds">
        <xsl:call-template name="seconds">
          <xsl:with-param name="time" select="$refPointTime"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="currentSeconds">
        <xsl:call-template name="seconds">
          <xsl:with-param name="time" select="time"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="secondsUsed" select="$currentSeconds - $refPointSeconds"/>

      <xsl:if test="not($isBeginRecord)">
        <xsl:attribute name="secondsUsed">
          <xsl:value-of select="$secondsUsed"/>
        </xsl:attribute>
      </xsl:if>

      <xsl:variable name="secondsSinceStart" select="$currentSeconds - $firstEntrySeconds"/>
      <xsl:attribute name="secondsSinceStart">
        <xsl:value-of select="$secondsSinceStart"/>
      </xsl:attribute>

      <xsl:variable name="exeedsThresholdTime" select="$secondsUsed &gt; $thresholdTime" />
      <xsl:attribute name="exeedsThresholdTime">
        <xsl:value-of select="$exeedsThresholdTime and not($isBeginRecord)"/>
      </xsl:attribute>

      <xsl:attribute name="tick">
        <xsl:value-of select="round($secondsSinceStart div $visualTickEveryXSeconds)"/>
      </xsl:attribute>

      <xsl:attribute name="tickPosition">
        <xsl:value-of select="$secondsSinceStart mod $visualTickEveryXSeconds"/>
      </xsl:attribute>

      <xsl:copy-of select="*"/>

    </xsl:copy>
  </xsl:template>


  <xsl:template match="/">
    <xsl:apply-templates select="$annotatedActivity"/>
  </xsl:template>
  
  <xsl:template match="annotatedActivity">
    <head>
      <title>Activity Monitor Log</title>
      <style type="text/css" xml:space="preserve">
        body{ text-align: left; width: 100%;  font-family: Verdana, sans-serif; }

        table{ border: none;  border-collapse: separate;  width: 100%; table-layout: fixed;}

        h1 { font-size: 24px;  font-weight: bold; }
        h2 { font-size: 18px;  font-weight: bold; }

        th{ background: #d0d0d0;  font-weight: bold;  font-size: 10pt;  text-align: left; }
        tr{ background: #eeeeee}
        td, th{ font-size: 8pt;  padding: 1px;  border: none; }

        tr td, tr th {
          padding: 4px;
        }
        
        tr.tick td {
          font-size: 0.8em;
          font-weight: bold;
          background-color: #FFAAAA;
        }

        tr.warning td{
          background-color:yellow;
          color:black;
        }

        tr.error td {
          background-color:red;
          color:black;
        }

        tr.exeedsThresholdTime {
          color: red;
        }

        tr.beginPackageLoad td {

        }

        tr.endPackageLoad td {
          background-color: #d0d0d0;
        }

        a:hover{text-transform:uppercase;color: #9090F0;}
        
        .authorInfo, h2 span { font-size: 10px; }
        
        .decription .path {
          font-family: 'Courier New';
        }
      </style>
    </head>

    <body>
      <h1>
        Activity Monitor Log Profiler <a class="authorInfo" href="https://github.com/lcorneliussen/ActivityLogProfiler/edit">... by Lars Corneliussen</a>
      </h1>
      <table>
        <tr>
          <td>Infos:</td>
          <td>
            <xsl:value-of select="count(entry[type='Information'])"/>
          </td>
        </tr>
        <tr>
          <td>Warnings</td>
          <td>
            <xsl:value-of select="count(entry[type='Warning'])"/>
          </td>
        </tr>
        <tr>
          <td>Errors</td>
          <td>
            <xsl:value-of select="count(entry[type='Error'])"/>
          </td>
        </tr>
        <tr>
          <td>Time span</td>
          <td>
            ~ <xsl:value-of select="round($lastEntrySeconds - $firstEntrySeconds)"/> total seconds
          </td>
        </tr>
      </table>

      <h2>Hot Spots <span>(&gt; <xsl:value-of select="$thresholdTime"/> second(s))</span></h2>
      <table class="hotspots">
        <tr>
          <th style="width:30px;text-align:center;">#</th>
          <th style="width:100%">Description</th>
          <th style="width:120px">Used Seconds</th>
        </tr>
        <xsl:for-each select="entry[number(@secondsUsed) &gt;= $thresholdTime]">
          <xsl:sort data-type="number" select="@secondsUsed" order="descending"/>
          <tr>
            <td class="id" align="right">
              <a href="#{record}"><xsl:value-of select="record"/></a>
            </td>
            <td class="description">
              <xsl:value-of select="description"/>
              <xsl:if test="path">, in <span class="path">
                  <xsl:value-of select="path"/>
                </span>
              </xsl:if>
              <xsl:if test="guid">
                <xsl:value-of select="guid"/>
              </xsl:if>
            </td>
            <td align="right" class="seconds">
              <xsl:value-of select="round(number(@secondsUsed) * 1000) div 1000"/> seconds
            </td>
          </tr>
        </xsl:for-each>
      </table>

      <h2>Log Entries</h2>
      <table>
        <tr>
          <th style="width:30px;text-align:center;">#</th>
          <th style="width:50px">Type</th>
          <th style="width:80%">Description</th>
          <th style="width:150px">GUID</th>
          <th style="width:50px">Hr</th>
          <th style="width:20%">Source</th>
          <th style="width:155px">Time (UTC)</th>
        </tr>
        <xsl:apply-templates/>
      </table>

    </body>
  </xsl:template>

  <xsl:template match="entry">
    <!-- example 
        
          <entry correlatingBeginRecordNumber="num" >
            <record>136</record>
            <time>2004/02/26 00:42:59.706</time>
            <type>Error</type>
            <source>Microsoft Visual Studio</source>
            <description>Loading UI library</description>
            <guid>{00000000-0000-0000-0000-000000000000}</guid>
            <hr>800a006f</hr>
            <path></path>
        </entry>
        
        -->

    <xsl:variable name="_classes">
      <xsl:choose>
        <xsl:when test="type='Information'">info </xsl:when>
        <xsl:when test="type='Warning'">warning </xsl:when>
        <xsl:when test="type='Error'">error </xsl:when>
      </xsl:choose>

      <xsl:if test="@correlatingBeginRecordNumber">endPackageLoad </xsl:if>

      <xsl:if test="@exeedsThresholdTime='true'">exeedsThresholdTime </xsl:if>
    </xsl:variable>

    <xsl:variable name="classes" select="normalize-space($_classes)"/>

    <xsl:variable name="currentTick" select="@tick"/>

    <tr class="{$classes}">
      <td class="number" align="right">
        <a name="{record}">
          <xsl:value-of select="record"/>
        </a>
      </td>
      <td class="type">
        <xsl:if test="type != 'Information'">
          <xsl:value-of select="type"/>
        </xsl:if>
      </td>
      <td class="description">
        <xsl:value-of select="description"/>
        <xsl:if test="path"> 
          <br/>&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;<xsl:value-of select="path"/>
        </xsl:if>
      </td>
      <td class="guid">
        <xsl:value-of select="guid"/>
      </td>
      <td class="hr">
        <xsl:value-of select="hr"/>
      </td>
      <td class="source">
        <xsl:value-of select="source"/>
      </td>
      <td class="time" align="center">
        <xsl:value-of select="time"/>
        <xsl:if test="@correlatingBeginRecordNumber or @exeedsThresholdTime='true'">
          <br/> <b>used <xsl:value-of select="round(number(@secondsUsed) * 1000) div 1000"/> seconds <br/> since 
            <xsl:choose>
              <xsl:when test="@correlatingBeginRecordNumber">
                <a href="#{@correlatingBeginRecordNumber}">
                  #<xsl:value-of select="@correlatingBeginRecordNumber"/>
                </a>
              </xsl:when>
              <xsl:otherwise>last record</xsl:otherwise>
            </xsl:choose></b>
        </xsl:if>
      </td>
    </tr>

    <xsl:if test="($annotatedActivity/entry[@tick=$currentTick])[1]/record = record">
      <tr class="tick">
        <td colspan="7" align="center">
          ~ <xsl:value-of select="@tick"/>
          <xsl:choose>
            <xsl:when test="$visualTickEveryXSeconds = 1"> seconds</xsl:when>
            <xsl:otherwise> ticks</xsl:otherwise>
          </xsl:choose> passed
        </td>
      </tr>
    </xsl:if>

  </xsl:template>

  

  <xsl:template name="seconds">
    <xsl:param name="time"/>

    <xsl:value-of select="number(substring($time, 12,2)) * 60 * 60 + number(substring($time, 15,2)) * 60 + number(substring($time, 18,2)) + number(substring($time, 21,3)) div 1000"/>
  </xsl:template>

</xsl:stylesheet>