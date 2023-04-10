-- ein Wizard-Mod von Großmeister
-- 5.11.2020
-- wesentlich ueberarbeitet am 29.08.2022
-- Korrekturen an Funktion WechselUI von mineslime am 30.11.2022
-- globale Variablen
Punkte = {}                  -- Punkteliste
Stich = {}                   -- Stichliste (der aktuellen Runde)
ZeilenZahl = 20              -- Standardzahl der Zeilen in UI-Tabelle
SpaltenZahl = 12             -- Standardzahl der Spalten in UI-Tabelle
glob_Runde_Num = 0           -- Rundenzaehler
glob_Startspieler = ''       -- welcher Spieler beginnt diese Runde?
glob_Spieler_am_Zug = ''     -- welcher Spieler muss als naechstes Ansagen?
Modus = 'Starten'            -- es gibt vier Modi: 'Starten', 'Ansagen', 'Spielen' und 'Auswerten'; jede Runde startet im Ansagenmodus;
                             -- bis zum ersten Ausgeben befindet sich das Spiel im Startmodus
Option = 'manu'              -- zwei Spieloptionen: 'auto' = automatisches Einsammeln der Stiche; 'manu' = manuelles Einsammeln
Verzoegerung = 2             -- Verzoegerungszeit im automatischen Modus bis Stich eingesammelt wird in Sekunden
Sprache = 'Deutsch'          -- Standardeinstellung der Sprache: Deutsch
ErwarteSpielerEingabe = ''   -- falls Z als Trumpfkarte aufgedeckt wird darf Geber Trumpffarbe auswaehlen, Eingabe erfolgt ueber Chat
                             -- ErwarteSpielerEingabe gibt an ob aktuell eine solche Eingabe erwartet wird und wenn ja von welcher Farbe
-- GUID der Counter der Spieler (guid_counter["White] = GUID des weissen Counters etc.)                             
guid_counter = {Blue = 'b6779d', White = 'eedab4', Red= 'cb4aa5', Teal = '9a45d1', Yellow = '4e9e34', Orange = '422e5d'}            
-- GUID der Spielertaster
guid_schalter = {Blue = '918048', White = 'd40e2d', Red = '2e3f8d', Teal = '992804', Yellow = '5ffdb2', Orange = 'b25d00'}
collectZoneGUID = '608575'   -- Spielflaeche
kerze_guid = '290d19'        -- Kerze fuer Korrekturfunktionen
tischplatte_guid = '437cd7'
erste_Runde_seit_Laden = false
Trumpf_Farbe = ''            -- Trumpffarbe dieser Runde
Stich_Anspieler = ''         -- wer in diesem Stich anspielt
Sortieren = {Blue = false, White = false, Red = false, Teal = false, Yellow = false, Orange = false} -- Karten werden standardmaessig nicht
                                                                                                     -- sortiert
Karten = {Blue={}, White = {}, Red = {}, Teal = {}, Yellow = {}, Orange = {}} -- Karten je Spieler
neues_Deck_bereit = false
                             
function RundenZahlAbrufen()
  return glob_Runde_Num
end  

function StartspielerAbrufen()
  return glob_Startspieler
end  

function ModusAbrufen()
  return Modus
end

function SpracheAbrufen()
  return Sprache
end

function UebergebeStartspieler(lok_Startspieler)
-- uebernimmt die Variable Startspieler aus anderen Skripten
  glob_Startspieler = lok_Startspieler
end

function AendereStichzahl(eingabe)
-- aendert die gezaehlte Anzahl an Stichen bei einem Spieler
-- erwartete Eingabe: Feld mit [1] = Farbe des Spielers bei dem Aenderung vorgenommen wird
--                             [2] = Wert um den Stichzahl geaendert wird
  local spielerfarbe = eingabe[1]
  local UmWert = eingabe[2]
  
  if Stich[spielerfarbe] != nil then
    Stich[spielerfarbe] = Stich[spielerfarbe] + UmWert
-- Zaehler aktualisieren    
    getObjectFromGUID(guid_counter[spielerfarbe]).editButton({index=0, label=tostring(Stich[spielerfarbe])})  
  end  
end

function AenderePunktzahl(eingabe)
-- aendert die Gesamtpunktzahl bei einem Spieler
-- erwartete Eingabe: Feld mit [1] = Farbe des Spielers bei dem Aenderung vorgenommen wird
--                             [2] = Wert um den Punktzahl geaendert wird
  local spielerfarbe = eingabe[1]
  local UmWert = eingabe[2]
  
  if Punkte[spielerfarbe] != nil then
    Punkte[spielerfarbe] = Punkte[spielerfarbe] + UmWert
  else
    Punkte[spielerfarbe] = UmWert
  end
-- UI-Tabelle aktualisieren
  if glob_Runde_Num > 1 then
    Zeile = glob_Runde_Num - 1
    Eintragen(spielerfarbe, Zeile, "Punkte", Punkte[spielerfarbe])  
  else
    Eintragen(spielerfarbe, glob_Runde_Num, "Punkte", Punkte[spielerfarbe])  
  end  
-- UI-Tabelle wird eingeblendet
  UI.setAttribute("Frame", "visibility", "Black|Grey|Blue|White|Red|Teal|Yellow|Orange")
end

function AendereAnsage(eingabe)
-- aendert die fuer diese Runde angesagte Stichzahl bei einem Spieler
-- erwartete Eingabe: Feld mit [1] = Farbe des Spielers bei dem Aenderung vorgenommen wird
--                             [2] = Wert um den die Ansage geaendert wird
  local spielerfarbe = eingabe[1]
  local UmWert = eingabe[2]
  
  local Ansage = Auslesen(spielerfarbe, glob_Runde_Num, "Ansage")
  Ansage = Ansage + UmWert
  
-- UI-Tabelle aktualisieren
  Eintragen(spielerfarbe, glob_Runde_Num, "Ansage", Ansage)  
    
-- UI-Tabelle wird eingeblendet
  UI.setAttribute("Frame", "visibility", "Black|Grey|Blue|White|Red|Teal|Yellow|Orange")  
end

function AbsBetrag(zahl)
-- gibt den Absolutbetrag einer eingegebenen Zahl zurueck
  assert(type(zahl) == "number", "AbsBetrag erwartet eine Zahl.")
  return zahl >= 0 and zahl or -zahl
end

function FarbreihenfolgeInZahl(InListe)
-- gibt eine Tabelle zurueck, die die Reihenfolge in der
-- aktuellen Runde numerisch festlegt
-- jedem Spieler wird ein Wert zwischen 1 und 12 zugewiesen
-- InListe soll eine Zuordnungstabelle von Spieler zu Farben sein
  local SpielerListe = {}
  local num_letzter = 0  -- Zahlwert des letzten Startspielers

  for i,v in pairs(InListe) do
-- 1. Farben in Positionen uebersetzen  
    if v == 'Blue' then
      SpielerListe[i] = 1
    else
      if v == 'White' then
        SpielerListe[i] = 2
      else
        if v == 'Red' then
          SpielerListe[i] = 3
        else
          if v == 'Teal' then
            SpielerListe[i] = 4
          else
            if v == 'Yellow' then
              SpielerListe[i] = 5
            else
              SpielerListe[i] = 6
            end
          end
        end
      end
    end
  end  
-- 2. Startspieler der letzten Runde suchen und nach hinten ruecken        
  for i,v in pairs(InListe) do
    if v == glob_Startspieler then
      num_letzter = SpielerListe[i]
      SpielerListe[i] =  SpielerListe[i] + 6
    end
  end
-- 3. Spieler vor dem letzten Startspieler nach hinten ruecken
  for i,v in pairs(InListe) do
    if SpielerListe[i] < num_letzter then
      SpielerListe[i] =  SpielerListe[i] + 6      
    end
  end
  return SpielerListe
end    

function naechsterSpieler(aktuellerSpieler)
-- bestimmt den Spieler der Spielerliste, der nach dem aktuellen dran ist
-- Ausgabewert: Farbe des bestimmten Spielers
  local HilfsListe = FarbreihenfolgeInZahl(getSeatedPlayers())
  local naechster = ''
  local index = 0        -- Position von aktuellerSpieler in Spielerlisten
  local hoechstWert = 0  -- hoechster numerischer Wert eines Spielers nach FarbreihenfolgeInZahl
  local tiefstWert = 13  -- entsprechend niedrigster Wert
  local naechsthoeherer = 13 -- naechst hoeherer Wert nach aktuellerSpieler
  
  for i,v in pairs(getSeatedPlayers()) do
-- bestimme Index    
    if v == aktuellerSpieler then
      index = i
    end

-- bestimmte hoechstWert und tiefstWert     
    if HilfsListe[i] > hoechstWert then
      hoechstWert = HilfsListe[i]
    end
    if HilfsListe[i] < tiefstWert then
      tiefstWert = HilfsListe[i]
    end
  end
  
-- Fall 1: aktuellerSpieler hat den hoechsten Indexwert -> naechster Spieler hat den tiefsten
  if HilfsListe[index] == hoechstWert then
    for i,v in pairs(getSeatedPlayers()) do
      if HilfsListe[i] == tiefstWert then
        naechster = v
      end
    end
  else
-- Fall 2: es gibt einen Spieler mit hoeherem Wert als aktuellerSpieler,
-- dann folgt als naechstes derjenige mit dem naechst hoeheren Wert  
-- I. bestimme naechsthoeherer
    for i,v in pairs(getSeatedPlayers()) do
      if (HilfsListe[i] > HilfsListe[index]) and (HilfsListe[i] < naechsthoeherer) then
        naechsthoeherer = HilfsListe[i]
        naechster = v
      end
    end
  end
  return naechster             
end

function HaendeLeer(spielerliste)
-- prueft ob noch jemand Karten in der Hand haelt
  local alles_weg = true
  local HandInhalt = {}

  for _,v in pairs(spielerliste) do
     HandInhalt = Player[v].getHandObjects()
     local KartenInHand = {}
	 for _,w in pairs(HandInhalt) do
	   if w.tag == "Card" then
         table.insert(KartenInHand,w)
	   end
	 end
     
     if #KartenInHand > 0 then
       alles_weg = false
--       print(Player[v].steam_name .. ' hat noch ' .. #KartenInHand .. ' Karten.')
     end
   end    
  return alles_weg
end

function StarteAnsagen()
  Modus = 'Ansagen'
 
  for _,v in pairs(getSeatedPlayers()) do
-- setzt Buttons aller Spieler in Wartemodus    
    getObjectFromGUID(guid_schalter[v]).call("ZustandsWechsel",0)

    
-- macht sie sichtbar falls "auto" Modus sie zuvor versteckt hat    
    getObjectFromGUID(guid_schalter[v]).setInvisibleTo({})

    
-- Zaehler aller Spieler werden auf Null zurueckgesetzt    
    getObjectFromGUID(guid_counter[v]).call("NullSetzen")
    
-- UI der Zaehler wechselt zurueck auf Ansagen
    getObjectFromGUID(guid_counter[v]).UI.setAttribute("obereZeile", "text", "") 
    if Sprache == 'Deutsch' then
      getObjectFromGUID(guid_counter[v]).UI.setAttribute("untereZeile", "text", "Ansage")     
    else
      getObjectFromGUID(guid_counter[v]).UI.setAttribute("untereZeile", "text", "Bid")     
    end
  end

-- Button des ersten Ansagers aktivieren    
  getObjectFromGUID(guid_schalter[glob_Startspieler]).call("ZustandsWechsel",1)
  
  glob_Spieler_am_Zug = glob_Startspieler
    
  
-- in der ersten Runde werden Spielernamen in Kopf der Tabelle eingetragen
  if  (glob_Runde_Num == 1) or erste_Runde_seit_Laden then
    for j,pl in pairs(getSeatedPlayers()) do  
-- bestimme die zugehörige Spalte (Startspieler zuerst, danach in Zugreihenfolge)
      local Spielernummer = 1
      if pl == glob_Startspieler then
        Spielernummer = 1
      else
        local spieler = glob_Startspieler
        repeat
          spieler = naechsterSpieler(spieler)
          Spielernummer = Spielernummer + 1
        until( spieler == pl )
      end 
      
-- trage Daten in ermittelte Spalte = Spielernummer ein
      local id = "P" .. Spielernummer
      if pl != 'White' then
        UI.setAttribute(id, "color", pl)
      else
        UI.setAttribute(id, "color", "Black")
      end  
      UI.setAttribute(id, "fontStyle", "Bold")
      UI.setAttribute(id, "text", Player[pl].steam_name)   
    end
    erste_Runde_seit_Laden = false
  end
end

function HandSortieren(Spielerfarbe)
-- sortiert die Karten in der Hand des ausführenden Spielers
  local cards = {}
  local handPos = {}
  local handObjects = Player[Spielerfarbe].getHandObjects()
        
  for i, j in pairs(handObjects) do
      table.insert(cards, {j, j.getName() .. j.getDescription()})
      table.insert(handPos, j.getPosition())
  end
        
  table.sort(cards, function(a, b) return a[2] < b[2] end) 
  for i, j in ipairs(cards) do
      j[1].setPosition(handPos[i])
  end
end

function Anmeldung(spielerfarbe)
-- Name des Spielers mit Farbe spielerfarbe  
  local SpielerName = ''
  for _,v in pairs(getSeatedPlayers()) do
    if v == spielerfarbe then
      SpielerName = Player[v].steam_name
    end  
  end
  
-- Verschiebung der Objekte in Relation zu Spieler 'White'
  local x_vers   = 0
  local z_vers   = 0
  local z_b_vers = 0
  local rot_y    = 0
  
  if spielerfarbe == 'Blue' then
    x_vers = 36
  else
    if spielerfarbe == 'Red' then
      x_vers = -36
    else
      if spielerfarbe == 'Yellow' then
        z_vers = 81.8
        z_b_vers = 90
        rot_y = 180
      else
        if spielerfarbe == 'Teal' then
          z_vers = 81.8
          x_vers = -36
          z_b_vers = 90
          rot_y = 180
        else
          if spielerfarbe == 'Orange' then
            z_vers = 81.8
            z_b_vers = 90
            x_vers = 36
            rot_y = 180
          end
        end
      end
    end            
  end  

-- platziere Counter an den richtigen Stellen
  local counter = getObjectFromGUID(guid_counter[spielerfarbe])
  Wait.frames(function()
    counter.setPosition({x=-7+x_vers, y=-0.9, z=-40.9+z_vers})
    counter.setRotation({x=0, y=180+rot_y, z=0})
    counter.setScale({x=4.38, y=1, z=4.38})
    if Sprache == 'Deutsch' then
      counter.setDescription('Zähler von ' .. SpielerName)
    else
      counter.setDescription('Counter of ' .. SpielerName)
    end
    counter.tooltip = true
    counter.interactable = true
    counter.setLock(true)
  end, 10)

-- platziere Spielerschalter an den richtigen Stellen 
  local schalter = getObjectFromGUID(guid_schalter[spielerfarbe])
  Wait.frames(function()
    schalter.setPosition({x=8+x_vers, y=-0.99, z=-45+z_b_vers})
    schalter.setRotation({x=0, y=180+rot_y, z=0})
    schalter.setScale({x=2.5, y=2.5, z=2.5})
    schalter.setName('Schalter' .. spielerfarbe)
    schalter.tooltip = false
    schalter.setColorTint(spielerfarbe)
    schalter.setLock(true)
  end, 10)
  
  if schalter.getButtons() == nil then
-- falls noetig erzeuge Buttonfunktion
    local parameter = {
      click_function = "SpielerbuttonKlick",
      function_owner = self,
      position       = {0, 0.4, 0},
      rotation       = {0, 180, 0},
      width          = 890,
      height         = 870,
      font_size      = 200,
      font_color     = {0, 0, 0},
      color          = spielerfarbe,
      tooltip        = "",
    }
    if Sprache == 'Deutsch' then
      parameter['label'] = "warten"
    else
      parameter['label'] = "wait"
    end
    schalter.createButton(parameter)
    schalter.interactable = false   
  end
end

function gSpielerbuttonKlick(parameters)
-- Parameteruebergabe durch [1] = Objekt; [2] = Spielerfarbe
  local obj = parameters[1]
  local Spielerfarbe = parameters[2]
  local StichAblage = { Blue  = {x=44, y= 0, z=-37 }, White = {x=8, y= 0, z=-37 }, Red = {x=-28, y= 0, z=-37 },
    Teal = {x=-28, y= 0, z=37 }, Yellow = {x=8, y= 0, z=37 }, Orange  = {x=44, y= 0, z=37 } }
    
  if ('Schalter' .. Spielerfarbe == obj.getName()) and obj.call("ZustandAbrufen") != 0 then
    if Modus == 'Ansagen' then
-- Funktion im Ansagemodus    
-- Ansage von Countereinstellung in Tabelle uebernehmen

      local AnsageWert = getObjectFromGUID(guid_counter[Spielerfarbe]).getButtons()[1].label
      
      Eintragen(Spielerfarbe, glob_Runde_Num, "Ansage", AnsageWert)
      if AnsageWert == '0' then
        if Sprache == 'Deutsch' then
          printToAll(Player[Spielerfarbe].steam_name .. ' nimmt diesmal lieber nichts.')
        else
          printToAll(Player[Spielerfarbe].steam_name .. ' announces not to take anything.')
        end
        else
          if AnsageWert == '1' then
            if Sprache == 'Deutsch' then
              printToAll(Player[Spielerfarbe].steam_name .. ' will sich mit einem Stich begnügen.')
            else
              printToAll(Player[Spielerfarbe].steam_name .. ' wants to take one trick.')
            end
          else
            if tonumber(AnsageWert) > glob_Runde_Num  then
              if Sprache == 'Deutsch' then              
                printToAll(Player[Spielerfarbe].steam_name .. ' nimmt gern alles und noch viel mehr: ' .. AnsageWert .. ' Stiche')
              else
                printToAll(Player[Spielerfarbe].steam_name .. ' would like to take everything and even more: ' .. AnsageWert .. ' ticks')
              end
            else  
              if Sprache == 'Deutsch' then
                printToAll(Player[Spielerfarbe].steam_name .. ' reklamiert ' .. AnsageWert .. ' Stiche für sich.' )
              else
                printToAll(Player[Spielerfarbe].steam_name .. ' claims ' .. AnsageWert .. ' tricks.' )
              end
            end  
          end
      end
      glob_Spieler_am_Zug = naechsterSpieler(Spielerfarbe)
-- voruebergehend ist dieser Button im Wartemodus
      obj.call("ZustandsWechsel", 0)     
            
      if glob_Spieler_am_Zug == glob_Startspieler then
-- Lege-Phase beginnt    
        Modus = 'Spielen'
        Stich_Anspieler = glob_Startspieler
-- UI-Tabelle schließt sich nach 2 Sekunden
        Wait.time(|| UI.setAttribute("Frame", "visibility", "Black"), 2)        
        local alleSpieler = {"Blue", "White", "Red", "Teal", "Yellow", "Orange", "Grey", "Black"}
        for i,v in pairs(getSeatedPlayers()) do
-- jeder kann nun Schalter in zweiter Funktion (Stich einsammeln) verwenden
          getObjectFromGUID(guid_schalter[v]).call("ZustandsWechsel",2)
          getObjectFromGUID(guid_counter[v]).call("NullSetzen")
          if Option == 'auto' then
-- im "auto" Modus wird der Button nicht gebraucht und daher versteckt             
            getObjectFromGUID(guid_schalter[v]).setInvisibleTo(alleSpieler)
          end
-- Anzeigen auf Stichzaehlen aendern
          local AnsageSpv = ''
          if v != Spielerfarbe then
            AnsageSpv = Auslesen(v, glob_Runde_Num, "Ansage")
          else                                     -- das Eintragen in die Tabelle scheint laenger zu dauern als der weitere Programmablauf
            AnsageSpv = AnsageWert                 -- bis hier, daher kann der Ansagewert des letzten Spielers nicht dort ausgelesen werden 
          end  
          
          if Sprache == 'Deutsch' then
            getObjectFromGUID(guid_counter[v]).UI.setAttribute("obereZeile", "text", "Stiche") 
            getObjectFromGUID(guid_counter[v]).UI.setAttribute("untereZeile", "text", "Ziel: " .. AnsageSpv)
          else
            getObjectFromGUID(guid_counter[v]).UI.setAttribute("obereZeile", "text", "Tricks") 
            getObjectFromGUID(guid_counter[v]).UI.setAttribute("untereZeile", "text", "Target: " .. AnsageSpv)
          end
-- Eintraege in Stichliste werden auf Null gesetzt
          Stich[v] = 0                    
        end
      else
-- weiter mit Ansage des naechsten Spielers           
        getObjectFromGUID(guid_schalter[glob_Spieler_am_Zug]).call("ZustandsWechsel",1)
      end
    else
      if Modus == 'Spielen' then
-- Funktion im Spielmodus 
-- Stich wird eingesammelt und kopfherum auf Spielerablage gestapelt
         obj.call("DruckAnimation")
-- sammle Karten nur ein wenn jeder gespielt hat -> KartenZahl = Anzahl der Spieler            
        if KartenZahlScriptZone() == #getSeatedPlayers() then
-- falls positiv: Lege gefundene Karten auf Stichstapel des Spielers
          Stichaufsammeln(Spielerfarbe)
-- Spieler darf naechsten Stich anspielen
          Stich_Anspieler = Spielerfarbe             
        else
-- falls jedoch nicht genug Karten auf dem Tisch liegen            
          if KartenZahlScriptZone() < #getSeatedPlayers() then
            if Sprache == 'Deutsch' then
              printToColor('Es haben noch nicht alle Spieler gelegt.', Spielerfarbe, {r=0.8,g=0,b=0})            
            else
              printToColor('Please wait until all players have played their card.', Spielerfarbe, {r=0.8,g=0,b=0})            
            end
          else
            if Sprache == 'Deutsch' then
              printToColor('Es liegen zu viele Karten auf dem Tisch. Entfernt bitte jene, die nicht zu diesem Stich gehören.',Spielerfarbe, {r=0.8,g=0,b=0})
            else
              printToColor('There are too many cards on the table. Please remove those that do not belong to this trick.',Spielerfarbe, {r=0.8,g=0,b=0})
            end            
          end  
        end

      else
        if Modus == 'Starten' then
          if Sprache == 'Deutsch' then
            printToColor('Du brauchst doch erst Karten, ehe du deine Stichzahl ansagen kannst.',Spielerfarbe, {r=0.8,g=0,b=0})
          else
            printToColor('Before stating how many tricks you will take, you have to get your cards.',Spielerfarbe, {r=0.8,g=0,b=0})
          end
        end       
      end  
    end  
  end
end


function Stichaufsammeln(Spielerfarbe)
-- sammelt die Karten in der Scriptzone ein und legt sie auf den Ablagestapel von Spielerfarbe
-- erhoeht Stichzaehler
-- beginnt Rundenauswertung falls alle Karten gespielt wurden
  local tableZone = getObjectFromGUID(collectZoneGUID)
  if tableZone then
    if tableZone != null then
-- folgende Abfrage falls waehrend "auto" Modus Karten vom Tisch entfernt wurden bevor diese Funktion mit Verzoegerung ausgefuehrt wurde    
      if KartenZahlScriptZone() == #getSeatedPlayers() then
        local StichAblage = { Blue  = {x=44, y= 0, z=-37 }, White = {x=8, y= 0, z=-37 }, Red = {x=-28, y= 0, z=-37 },
          Teal = {x=-28, y= 0, z=37 }, Yellow = {x=8, y= 0, z=37 }, Orange  = {x=44, y= 0, z=37 } }
        local objects = tableZone.getObjects()
        for i, object in pairs(objects) do
          if(object.tag == "Card" or object.tag =="Deck") then
            object.setRotation({0,90, 180})
            object.setPosition(StichAblage[Spielerfarbe])
          end
        end
-- und erhoehe dessen Stichzaehler um eins   
        Stich[Spielerfarbe] = Stich[Spielerfarbe] + 1
-- trage neuen Wert optischen Stichzaehler (=Counter) ein              
        getObjectFromGUID(guid_counter[Spielerfarbe]).editButton({index=0, label=tostring(Stich[Spielerfarbe])})
      
 
        local Ansage = Auslesen(Spielerfarbe, glob_Runde_Num, "Ansage")
        if Sprache == 'Deutsch' then
          broadcastToAll('Dieser Stich geht an '.. Player[Spielerfarbe].steam_name .. ' (' .. Stich[Spielerfarbe] .. '/' .. Ansage ..  ').') 
        else
          broadcastToAll(Player[Spielerfarbe].steam_name .. ' got this trick, (' .. Stich[Spielerfarbe] .. '/' .. Ansage ..  ').') 
        end
     
        
-- falls dies der letzte Stich der Runde war ( =kein Spieler hat mehr Karten auf der Hand) ...
        if HaendeLeer(getSeatedPlayers()) then
-- starte Auswertung in 2 Sekunden
          Wait.time(|| Auswertung(), 2)     
        end
      end  
    end    
  end
end

function table.contains(Liste, Objekt)
-- prueft ob table Liste Objekt als Element enthaelt
  for _, element in pairs(Liste) do
    if element == Objekt then
      return true
    end
  end
  return false
end



function KartenZahlScriptZone()
-- bestimmt die Anzahl der Objekte vom Typ 'Karte' in der Scriptzone
-- gibt die Anzahl zurueck
  local KartenZahl = 0    -- Zaehler der Karten in dieser Zone

-- pruefen ob ScriptZone existiert (sollte immer der Fall sein) 
  local tableZone = getObjectFromGUID(collectZoneGUID)
  if tableZone then
    if tableZone != null then
-- alle Karten in dieser Zone erfassen            
      local objects = tableZone.getObjects()
      for _, object in pairs(objects) do
        if object.tag == "Card" then
          KartenZahl = KartenZahl + 1    -- jede gefundene Karte erhoeht den Zaehler um eins
        else
          if object.tag =="Deck" then
            KartenZahl = KartenZahl + #object.getObjects()  -- jedes gefundene Deck erhoeht den Zaehler um die Anzahl seiner Elemente
          end
        end
      end
    end
  else
    if Sprache == 'Deutsch' then
      print("Tischzone nicht gefunden.", {r=0.8,g=0,b=0})
    else
      print("table zone not found", {r=0.8,g=0,b=0})
    end      
  end
  return KartenZahl
end      

function Warte()
  local start = os.time()
  local dauer = 10
  repeat
    coroutine.yield(0)
  until os.time() > start + dauer
  return 1
end


function FindeKarteIn(obj,table)
-- falls obj vom Typ "Card" ist, wird geprueft ob es sich in table befindet
  local Ausgabe = false
-- pruefen ob table existiert und nicht leer ist
  if table and obj.tag == "Card" then
    if table != null then
-- alle Karten in table erfassen       
      for _, object in pairs(table) do
        if object.tag == "Card" then
          if object == obj then
            Ausgabe = true
          end
        else
          if object.tag =="Deck" then
            objects_deck = object.getObjects()
            for _, object_deck in pairs(objects_deck) do
              if (object_deck.Name == obj.getName()) and (object_deck.Description == obj.getDescription()) then
                Ausgabe = true
              end
            end
          end
        end
      end
    end
  end          
  return Ausgabe
end            

function HoehereKarte(karte_1_f, karte_1_w, karte_2_f, karte_2_w)
-- ist karte_2 (Farbe=karte_2_f, Wert=karte_2_w) hoeher als karte_1 (Farbe=karte_1_f, Wert=karte_1_w)? 
-- Ausgabe wahr oder falsch
  local hoeher = false
-- Wann kann karte_2 hoeher als karte_1 sein?  
  if karte_1_f == ''                                          -- Karte 1 gibt es gar nicht
  or (karte_2_f == 'Z' and karte_1_f != 'Z')                  -- Z ist hoeher als alles bis auf vorherigen Z
  or (karte_1_f == 'N' and karte_2_f != 'N')                  -- alles bis auf N ist hoeher als N
  or (karte_2_f == karte_1_f and karte_2_w > karte_1_w)       -- gleiche Farbe hoeherer Wert
  or (karte_2_f == Trumpf_Farbe and karte_1_f != Trumpf_Farbe
    and karte_1_f != 'Z') then                                -- Trumpf vs. Nicht-Trumpf
    hoeher = true
  end  
  return hoeher
end

function WechselZuManu()
-- falls im "auto" Modus, wechsel zu "manu"

  if Option == 'auto' then
    Option = 'manu'
-- Sichtbarmachung versteckter Buttons zum Sticheinsammeln
    for _,v in pairs(getSeatedPlayers()) do
      getObjectFromGUID(guid_schalter[v]).setInvisibleTo({})
    end  
  end
end


function onObjectDrop(Spielerfarbe, obj)
-- ausgeloest wenn obj abgelegt wird
-- Effekt: wenn eine Karte in Scriptzone gelegt wird,
-- werden im "auto"-Modus komplette Stiche eingesammelt

-- falls "Spielen" Modus noch nicht begonnen hat, wird Karte zurueck auf die Hand gegeben
  if obj.tag == "Card" and Modus == "Ansagen" then
    obj.deal(1, Spielerfarbe)
    if Sprache == 'Deutsch' then
      printToColor('Bitte warten bis alle Ansagen getätigt wurden',Spielerfarbe, {r=0.8,g=0,b=0})
    else
      printToColor('Please wait until all players have placed their bids.',Spielerfarbe, {r=0.8,g=0,b=0})
    end
  else
    local tableZone = getObjectFromGUID(collectZoneGUID)
    if tableZone then
      if tableZone != nil then
-- wie viele Karten je Spieler auf Tischmitte liegen      
        local gespielt = {Blue = 0, White = 0, Red = 0, Teal = 0, Yellow = 0, Orange = 0}
-- gespielte Karte je Spieler        
        local gespielte_Karte = {Blue = {Farbe='', Wert=''}, White = {Farbe='', Wert=''}, Red = {Farbe='', Wert=''}, Teal = {Farbe='', Wert=''}, Yellow = {Farbe='', Wert=''}, Orange = {Farbe='', Wert=''}}
        

-- im "auto" Modus wird der Stich ggf. eingesammelt      
        --  print('aktuell liegen ' .. KartenZahlScriptZone() .. ' Karten aus.') -- HIERHIER (Hilfsinformation zu Testzwecken)
        if Option == 'auto' and KartenZahlScriptZone() == #getSeatedPlayers() then
-- hat jeder Spieler genau eine Karte gespielt?
          for _,o in pairs(tableZone.getObjects()) do            
            for _,p in pairs(getSeatedPlayers()) do
              if FindeKarteIn(o,Karten[p]) then
                gespielt[p] = gespielt[p] + 1
-- trage bereits die gespielte Karte je Spieler ein                
                gespielte_Karte[p].Farbe = o.getName()
                gespielte_Karte[p].Wert = o.getDescription()
              end    
            end          
          end
          
          local jeder_gespielt = true
          for _,p in pairs(getSeatedPlayers()) do
            if gespielt[p] != 1 then
              jeder_gespielt = false
            end
          end
          
-- falls positiv: bestimme Stichsieger 
          if jeder_gespielt then
            local hoechste_Karte = gespielte_Karte[Stich_Anspieler]
            local Stich_Farbe = Stich_Anspieler -- Farbe des Spielers mit hoechster Karte
            for _,p in pairs(getSeatedPlayers()) do
              if HoehereKarte(hoechste_Karte.Farbe, hoechste_Karte.Wert, gespielte_Karte[p].Farbe, gespielte_Karte[p].Wert) then
                hoechste_Karte = gespielte_Karte[p]
                Stich_Farbe = p
              end
            end
            
            
-- Lege gefundene Karten auf Stichstapel des Stichsiegers
            if id_aufsammeln != nil then
              Wait.stop(id_aufsammeln)
            end
            id_aufsammeln = Wait.time(|| Stichaufsammeln(Stich_Farbe), Verzoegerung)  
-- Spieler darf naechsten Stich anspielen
            Stich_Anspieler = Spielerfarbe        
          else
            if Option == 'auto' and KartenZahlScriptZone() > #getSeatedPlayers() then
              if Sprache == 'Deutsch' then
                printToColor('Es liegen zu viele Karten auf dem Tisch. Entfernt bitte jene, die nicht zu diesem Stich gehören.',Spielerfarbe,  {r=0.8,g=0,b=0})
              else
                printToColor('There are too many cards on the table. Please remove those that do not belong to this trick.',Spielerfarbe,  {r=0.8,g=0,b=0})
              end              
-- Wechsel in manuellen Modus = beste Loesung zur Fehlerbehebung?          
              if Sprache == 'Deutsch' then
                printToAll('Es liegen zu viele Karten auf dem Tisch: Stiche werden nun manuell aufgenommen.', {r=0.8,g=0,b=0})
              else
                printToAll('There are too many cards on the table. Tricks must now be claimed manually.', {r=0.8,g=0,b=0})
              end
              WechselZuManu()  
            end
          end    
        end        
      end
    end
  end
end



function Auswertung()
-- Funktion, die zu jedem Rundenende ausgeführt wird
-- Punktzahlabrechnung
  Modus = 'Auswerten'
-- Buttons inaktiv stellen  
  for _,v in pairs(getSeatedPlayers()) do    
    getObjectFromGUID(guid_schalter[v]).call("ZustandsWechsel",0)
  end
  
-- Abrechnung
  if Sprache == 'Deutsch' then
    printToAll('Ergebnis der ' .. glob_Runde_Num .. '. Runde:')
  else
    printToAll('Results of round ' .. glob_Runde_Num .. ':')
  end
  for i,v in pairs(getSeatedPlayers()) do  
-- in der ersten Runde Startpunktzahl auf Null setzen, sonst auf bisherige Punkte aufrechnen (oder im Falle, dass in Runde eins
-- bereits die Punktzahl durch den Spielleiter manuell geaendert wurde)
    local alt_Punkte = 0
    if glob_Runde_Num > 1 then
      alt_Punkte = Auslesen(v, glob_Runde_Num - 1, "Punkte")
      if alt_Punkte == '' then
        alt_Punkte = 0
      end
    end
    
-- neue Punktzahl
-- angesagte Stiche aus Tabelle auslesen
    local Ansage = Auslesen(v, glob_Runde_Num, "Ansage")
 
    if tostring(Stich[v]) == Ansage then
-- Ansage korrekt: neue Punktzahl = alt + 20 + angesagte Stichzahl * 10
      Punkte[v] = alt_Punkte + 20 + 10 * Stich[v]
      if Sprache == 'Deutsch' then
        printToAll(Player[v].steam_name .. ' hat angesagt: ' .. Ansage .. ', erhalten: ' .. Stich[v] .. ' -> +' .. tostring(20+10*Stich[v]) .. ' Punkte')
      else
        printToAll(Player[v].steam_name .. ' wanted to take: ' .. Ansage .. ', got: ' .. Stich[v] .. ' -> +' .. tostring(20+10*Stich[v]) .. ' points')
      end  
    else
      Punkte[v] = alt_Punkte - 10 * AbsBetrag(Stich[v] - Ansage)
      if Sprache == 'Deutsch' then
        printToAll(Player[v].steam_name .. ' hat angesagt: ' .. Ansage .. ', erhalten: ' .. Stich[v] .. ' -> -' .. tostring(10*AbsBetrag((Stich[v]-Ansage))) .. ' Punkte')
      else
        printToAll(Player[v].steam_name .. ' wanted to take: ' .. Ansage .. ', got: ' .. Stich[v] .. ' -> -' .. tostring(10*AbsBetrag((Stich[v]-Ansage))) .. ' points')
      end  
    end
-- Punktzahl in Tabelle eintragen    
    Eintragen(v, glob_Runde_Num, "Punkte", Punkte[v])
  end
  
-- UI-Tabelle wird eingeblendet
  UI.setAttribute("Frame", "visibility", "Black|Grey|Blue|White|Red|Teal|Yellow|Orange")
  
-- zum Starten der naechsten Runde erscheint ein Button auf dem Tisch
  local btn_pmt = {
      click_function = "neueRunde",
      function_owner = self,
      position = { 0, 11, 3.3},
      color = {0.204, 0.122, 0.078},
      font_color = {1, 1, 1},
      width = 4960,
      height = 1600,
      font_size = 800,
    }
  
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "nächste Runde"
    btn_pmt['tooltip'] = "nächste Runde beginnen"
  else
    btn_pmt['label'] = "next round"
    btn_pmt['tooltip'] = "start next round"
  end
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)
  
  btn_pmt = {
    click_function = "neueRunde",
    function_owner = self,
    color = {0.204, 0.122, 0.078},
    font_color = {1, 1, 1},
    width = 4960,
    height = 1600,
    font_size = 800,
    rotation = {0, 180, 0},
    position = { 0, 11, -4.2}
  } 
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "nächste Runde"
    btn_pmt['tooltip'] = "nächste Runde beginnen"
  else
    btn_pmt['label'] = "next round"
    btn_pmt['tooltip'] = "start next round"
  end
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)  
end

function Endauswertung()
-- zum Spielende: Bekanntgabe des Siegers
  local pmax = Punkte[glob_Startspieler]
  local sieger = glob_Startspieler
  local gleichstand = false
  
  for _,v in pairs(getSeatedPlayers()) do
    if pmax < Punkte[v] then
      sieger = v
      pmax = Punkte[v]
      gleichstand = false
    else
      if pmax == Punkte[v] and sieger != v then
        gleichstand = true
      end
    end  
  end
  
-- Verkuendung des Ergebnisses
  if not gleichstand then
    if Player[sieger].steam_name == 'großmeister' then
      broadcastToAll('Wenig überraschenderweise hat Großmeister gewonnen.', {r=0,g=0.8,b=0})
    else
      if Player[sieger].steam_name == 'Nuxxaa' then
        broadcastToAll('Wenn Nuxxaa die zwanzig Karten nicht in den eigenen Händen halten muss, kann sie sogar gewinnen.', {r=0.8,g=0,b=0.8} )
      else
        if Player[sieger].steam_name == 'Sarastro' then
          local e = true
          local h = ''
          for i, v in pairs(getSeatedPlayers()) do
            if e == true then
              if v != sieger then
                e = false
                h = 'und ' .. Player[v].steam_name
              end
            else
              if v != sieger then
                h = Player[v].steam_name .. ', ' .. h
              end  
            end
          end
          h = h .. ' haben Sarastro heute einmal gewinnen lassen. Wie nett von ihnen!'
          broadcastToAll(h, {r=0.8,g=0,b=0})
        else
          if Sprache == 'Deutsch' then
            broadcastToAll(Player[sieger].steam_name .. ' hat mit ' .. pmax .. ' Punkten gewonnen.', {r=1,g=0.84,b=0})
          else
            broadcastToAll(Player[sieger].steam_name .. ' has won with ' .. pmax .. ' points.', {r=1,g=0.84,b=0})
          end
        end
      end
    end       
  else
    if Sprache == 'Deutsch' then
      local hstring = 'Gewonnen haben ' .. Player[sieger].steam_name
    else
      local hstring = 'The winner are ' .. Player[sieger].steam_name
    end
    for _,v in pairs(getSeatedPlayers()) do
      if Punkte[v] == pmax and v != sieger then
        if Sprache == 'Deutsch' then
          hstring = hstring .. ' und ' .. Player[v].steam_name
        else
          hstring = hstring .. ' and ' .. Player[v].steam_name
        end
      end
    end
    broadcastToAll(hstring .. '.', {r=1,g=0.84,b=0})
  end  
end

function SpielAbbruch()
-- setzt das Spiel in den Startmodus zurueck und loescht alle bisherigen Ansagen und Punkte
  Modus = 'Starten'

-- Krakentisch konfigurieren
-- Auslagen vorbereiten
  if getObjectFromGUID('0c8d35') != nil then
    getObjectFromGUID('0c8d35').setState(1)  -- blaue Lade anfangs eingeklappt
  end
  if getObjectFromGUID('665355') != nil then
    getObjectFromGUID('665355').setState(1)  -- weisse Lade anfangs eingeklappt
  end
  if getObjectFromGUID('3c4e81') != nil then
    getObjectFromGUID('3c4e81').setState(1)  -- rote Lade anfangs eingeklappt
  end
  if getObjectFromGUID('661907') != nil then
    getObjectFromGUID('661907').setState(1)  -- gelbe Lade anfangs eingeklappt
  end
  if getObjectFromGUID('88b8d6') != nil then
    getObjectFromGUID('88b8d6').setState(1)  -- tuerkise Lade anfangs eingeklappt
  end
  if getObjectFromGUID('5dd89b') != nil then
    getObjectFromGUID('5dd89b').setState(1)  -- orange Lade anfangs eingeklappt
  end

-- Aufraeumfunktion falls noch Spawn-Objekte vom letzten Spielstand herumschweben
  Aufraeumen()  
  
-- Karten zusammenlegen  
  local objects = getAllObjects()
  for i, object in pairs(objects) do
    if(object.tag == "Card" or object.tag =="Deck") then
      object.setRotation({0,90,180})
      object.setPosition({55.4, 2, -3.8})
      object.setScale({2.68,1,2.68})
    end
  end
  
  glob_Runde_Num = 0
  glob_Startspieler = ''
  
-- Tabelle leeren
  UI.setAttribute("Frame", "visibility", "Black")
  for i=1,6 do
    local id = "P" .. i
    UI.setAttribute(id, "text", "")
    for j=1,20 do
      id = "R" .. j .. "P" .. i .. "_Punkte"
      UI.setAttribute(id, "text", "")      
      id = "R" .. j .. "P" .. i .. "_Ansage"
      UI.setAttribute(id, "text", "") 
    end
  end
  
-- alte Buttons vom Tisch entfernen
  if getObjectFromGUID(tischplatte_guid).getButtons() != nil then
    for i, k in ipairs(getObjectFromGUID(tischplatte_guid).getButtons()) do
      for j = 0, (i-1) do
        getObjectFromGUID(tischplatte_guid).removeButton(j)  -- doppelt sicheres loeschen der Buttons?? nach Bug bei einigen Spieler mit
      end                                                    -- removeButton(k.index)  
    end                                                    
  end  
  
-- Korrekturmodi deaktivieren
  getObjectFromGUID(kerze_guid).call("KorrekturmodiDeaktivieren")  
  
-- Neustart-Button
  local btn_pmt = {
      click_function = "neueRunde",
      function_owner = self,
      position = { 0, 11, 3.3},
      color = {0.204, 0.122, 0.078},
      font_color = {1, 1, 1},
      width = 4960,
      height = 1600,
      font_size = 800,
    }
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "neues Spiel"
    btn_pmt['tooltip'] = "neues Spiel beginnen"
  else
    btn_pmt['label'] = "new game"
    btn_pmt['tooltip'] = "start a new game"
  end
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)
  
  btn_pmt = {
    click_function = "neueRunde",
    function_owner = self,
    label = "neues Spiel",
    color = {0.204, 0.122, 0.078},
    font_color = {1, 1, 1},
    width = 4960,
    height = 1600,
    tooltip = "neues Spiel beginnen",
    font_size = 800,
    rotation = {0, 180, 0},
    position = { 0, 11, -4.2}
  }
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "neues Spiel"
    btn_pmt['tooltip'] = "neues Spiel beginnen"
  else
    btn_pmt['label'] = "new game"
    btn_pmt['tooltip'] = "start a new game"
  end  
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)     
end

function Eintragen(Spielerfarbe, Zeile, Typ, Wert)
-- Spielerfarbe legt Spalte fest in der Eintragung vorgenommen wird
-- Zeile entspricht der Rundenzeile der Tabelle
-- Typ: "Ansage" oder "Punkte"
-- Wert: einzutragender Wert
-- wenn durch (Spielerfarbe, Zeile, Typ) bestimmte Zelle der Tabelle nicht existiert, passiert nichts

-- pruefe ob Spielerfarbe eine gueltige Farbe ist
  local gueltigeEingabe = false
  for _,v in pairs({'Blue', 'White', 'Red', 'Teal', 'Yellow', 'Orange'}) do
    if Spielerfarbe == v then
      gueltigeEingabe = true
    end  
  end 
  
-- ist Pruefung erfolgreich ...  
  if gueltigeEingabe then
    local Spielernummer = 0
-- ... bestimme Spalte, die zu Spielerfarbe gehoert
    for i,v in pairs(getSeatedPlayers()) do
      local id = "P" .. i
      if UI.getAttributes(id).text == Player[Spielerfarbe].steam_name then
        Spielernummer = i
      end  
    end


    local id = "R" .. Zeile .. "P" .. Spielernummer .. "_" .. Typ
    UI.setAttribute(id, "text", Wert) 
  end  
end

function Auslesen(Spielerfarbe, Zeile, Typ)
-- liest den eingetragenen Wert aus Tabelle aus
-- Spielerfarbe bestimmt die Spalte, Zeile die Zeile
-- Typ ist entweder "Ansage" oder "Punkte"
-- falls ungueltige Spielerfarbe oder Zeile angefragt wurde, ist Ausgabe=0

-- bestimme Spalte, die zu Spielerfarbe gehoert
  local Spielernummer = 0
  for i,v in pairs(getSeatedPlayers()) do
    local id = "P" .. i
    if UI.getAttributes(id).text == Player[Spielerfarbe].steam_name then
      Spielernummer = i
    end
  end

-- Auslesen dieses Feldes sofern es existiert
  local Ausgabe = '0'
  if (Spielernummer > 0) and (Zeile > 0)  -- Spielerfarbe muss einem Spieler am Tisch zugeordnet sein, Zeile > 0
    and (((Spielernummer < 4) and (Zeile <= 20))          -- bei drei Spielern darf Zeile maximal zwanzig sein
      or ((Spielernummer == 4) and (Zeile <= 15))         -- bei vier Spielern bis zu Zeile 15
      or ((Spielernummer == 5) and (Zeile <= 12))         -- bei fuenf Spielern bis zu Zeile 12
      or ((Spielernummer == 6) and (Zeile <= 10)) ) then  -- bei sechs Spielern bis zu Zeile 10
    local id = "R" .. Zeile .. "P" .. Spielernummer .. "_" .. Typ
    Ausgabe = UI.getAttributes(id).text
  end  
  return Ausgabe
end

function Aufraeumen()
-- sammelt verschobene Objekte ein
-- Schalter wegraeumen
  for i,v in pairs(guid_schalter) do
    getObjectFromGUID(v).setPosition({x=0, y=-0.5, z=0})
    getObjectFromGUID(v).setRotation({x=0, y=0, z=180})
  end

-- Zaehler wegraeumen  
  for i,v in pairs(guid_counter) do
    getObjectFromGUID(v).setPosition({x=2, y=-0.5, z=2}) 
    getObjectFromGUID(v).setRotation({x=0, y=0, z=180})
-- Tooltip deaktivieren
    getObjectFromGUID(v).tooltip = false
-- nicht auswählbar
    getObjectFromGUID(v).interactable = false           
  end            
end

function onChat(text, Spieler)
  if glob_Startspieler == "" and (text == "!Startspieler" or text == "\"!Startspieler\"") then
    local Startspieler = Spieler.color
-- da Startspieler zu Rundenbeginn weiterspringt muss Spieler rechts vom eigentlichen Startspieler eingetragen werden
    for i,v in ipairs(getSeatedPlayers()) do
      if i != 1 then
        Startspieler = naechsterSpieler(Startspieler)
      end 
    end
    glob_Startspieler = Startspieler     
  end  
  if text == '!hilfe' then
    printToColor('mögliche Befehle (alle Spieler) sind:',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('\"!sortieren ein\" -- sortiert die Karten auf der Hand automatisch (je Spieler konfigurierbar)',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('\"!sortieren aus\" -- deaktiviert das automatische Sortieren',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('Nur wenn ein Z bei der Trumpfwahl aufgedeckt wurde, kann der Geber dieser Runde binnen 20 Sekunden durch Eingabe von \"blau\", \"rot\", \"gelb\" oder \"grün\" bzw. \"gruen\" wählen welche Farbe Trumpf sein soll.',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('zusätzliche Befehle für Host:',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!auto\" -- schaltet automatisches Einsammeln vollständiger Stiche ein',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!manu\" -- deaktiviert das automatische Einsammeln der Stiche',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!t x\" -- setzt die Verzögerung des Einsammelns im automatischen Modus auf x Sekunden',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!Stapel_entsperren\" -- macht den Kartenstapel interagierbar',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!Stiche_korrigieren\" -- aktiviert den Korrekturmodus für die Stichzahl',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!Punkte_korrigieren\" -- aktiviert den Korrekturmodus für die Punktzahl',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!Ansage_korrigieren\" -- aktiviert den Korrekturmodus für die Ansagen',Spieler.color, {r=0,g=0.8,b=0})
  end
  
  if text == '!help' then
    printToColor('possible commands (for all players) are:',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('\"!sort on\" -- sorts the cards in the hand automatically (configurable per player)',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('\"!sort off\" -- deactivates automatic sorting',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('Only if a Z has been revealed in the trump selection, the dealer of this round can choose within 20 seconds by entering \"blue\", \"red\", \"yellow\" or \"green\" to choose which color should be trump.',Spieler.color, {r=0.8,g=0.8,b=0.8})
    printToColor('additional commands for the host:',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!auto\" -- activates automatic gathering of the tricks',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!manu\" -- deactivates automatic gathering of the tricks',Spieler.color, {r=0,g=0.8,b=0})
    printToColor('\"!t x\" -- sets the delay of collecting in automatic mode to x seconds',Spieler.color, {r=0,g=0.8,b=0})
  end
  
  if text == '!Deutsch' then
    Sprache = 'Deutsch'
    printToAll('Spracheinstellung: Deutsch')
    getObjectFromGUID(kerze_guid).call("Sprachwechsel",Sprache)
  end
  
  if text == '!English' then
    Sprache = 'English'
    printToAll('Language has been set to English.')
    getObjectFromGUID(kerze_guid).call("Sprachwechsel",Sprache)
  end
  
  if text == '!sortieren ein' then
    Sortieren[Spieler.color] = true 
    HandSortieren(Spieler.color)
    printToColor('Deine Karten werden fortan automatisch sortiert. Zum Deaktivieren \"!sortieren aus\" eingeben',Spieler.color, {r=0.8,g=0.8,b=0.8})
  else
    if text == '!sortieren aus' then
      Sortieren[Spieler.color] = false
      printToColor('Deine Karten werden nicht mehr automatisch sortiert. Zum Aktivieren des Sortierens \"!sortieren ein\" eingeben',Spieler.color, {r=0.8,g=0.8,b=0.8})
    end
  end
  
  if text == '!sort on' then
    Sortieren[Spieler.color] = true 
    HandSortieren(Spieler.color)
    printToColor('Your cards will be sorted automatically from now on. To deactivate, enter \"!sort off\"',Spieler.color, {r=0.8,g=0.8,b=0.8})
  else
    if text == '!sort off' then
      Sortieren[Spieler.color] = false
      printToColor('Your cards will no longer be sorted automatically. To activate sorting, enter \"!sort on\"',Spieler.color, {r=0.8,g=0.8,b=0.8})
    end
  end
  
  if text == '!auto' and Spieler.host then
    if Modus != 'Spielen'                -- Umstellen auf "auto" Modus nur möglich wenn nicht in "Spielen" Phase oder ...
    or KartenZahlScriptZone() == 0 then  -- ... noch keine Karte ausgespielt
      if Trumpf_Farbe == 'Z' then
-- Geber dieser Runde darf die Trumpffarbe waehlen
-- welcher Spieler ist das?
        local Geber = glob_Startspieler        
        for i,v in ipairs(getSeatedPlayers()) do
          if i != 1 then
            Geber = naechsterSpieler(glob_Startspieler)
          end 
        end        
        ErwarteSpielerEingabe = Geber
-- Nachricht an Geber            
        local Meldung = function ()
          if Sprache == 'Deutsch' then
            broadcastToColor('Bitte Trumpffarbe wählen: \"blau\", \"gelb\", \"rot\" oder \"grün\" bzw. \"gruen\"  in den Chat eingeben',Geber)
          else
            broadcastToColor('Please choose the color of trump: Enter \"blue\", \"yellow\", \"red\" or \"green\"',Geber)
          end
        end
        Meldung()
        id_wt1 = Wait.time(Meldung, 5)
        id_wt2 = Wait.time(Meldung, 10)
        id_wt3 = Wait.time(Meldung, 15)
            
        local Nach_Warten = function()
          Trumpf_Farbe=''
          if Sprache == 'Deutsch' then
            printToAll('keine Trumpffarbe ausgewählt', {r=0,g=0,b=0.8})
          else
            printToAll('No trump color has been chosen', {r=0,g=0,b=0.8})
          end
          Option = 'auto'
          ErwarteSpielerEingabe = ''
          if Sprache == 'Deutsch' then
            printToAll('Die Stiche werden jetzt automatisch nach ' .. Verzoegerung .. ' Sekunden eingesammelt.', {r=0,g=0.8,b=0})
          else
            printToAll('The tricks will now be automatically collected with a delay of ' .. Verzoegerung .. ' seconds.', {r=0,g=0.8,b=0})
          end
-- verstecke unnoetige Buttons
          if Modus == 'Spielen' then
            local alleSpieler = {"Blue", "White", "Red", "Teal", "Yellow", "Orange", "Grey", "Black"}
            for i,v in pairs(getSeatedPlayers()) do              
              getObjectFromGUID(guid_schalter[v]).setInvisibleTo(alleSpieler)
            end  
          end
        end
        local Umstellen_Auto = function()
          Option = 'auto'
-- verstecke unnoetige Buttons
          if Modus == 'Spielen' then
            local alleSpieler = {"Blue", "White", "Red", "Teal", "Yellow", "Orange", "Grey", "Black"}
            for i,v in pairs(getSeatedPlayers()) do              
              getObjectFromGUID(guid_schalter[v]).setInvisibleTo(alleSpieler)
            end  
          end
            
-- beende Timer mit Meldung            
          if id_wt1 != nil then
            Wait.stop(id_wt1)
          end
          if id_wt2 != nil then
            Wait.stop(id_wt2)
          end  
          if id_wt3 != nil then  
            Wait.stop(id_wt3)
          end  
          if Sprache == 'Deutsch' then
            printToAll('Die Stiche werden jetzt automatisch nach ' .. Verzoegerung .. ' Sekunden eingesammelt.', {r=0,g=0.8,b=0})
          else
            printToAll('The tricks will now be automatically collected with a delay of ' .. Verzoegerung .. ' seconds.', {r=0,g=0.8,b=0})
          end
        end
        Wait.condition(Umstellen_Auto, function() return Trumpf_Farbe != 'Z' end,20,Nach_Warten)
      else
        Option = 'auto'
-- verstecke unnoetige Buttons
        if Modus == 'Spielen' then
          local alleSpieler = {"Blue", "White", "Red", "Teal", "Yellow", "Orange", "Grey", "Black"}
          for i,v in pairs(getSeatedPlayers()) do
            if Option == 'auto' then              
              getObjectFromGUID(guid_schalter[v]).setInvisibleTo(alleSpieler)
            end  
          end
        end
        if Sprache == 'Deutsch' then
          printToAll('Die Stiche werden jetzt automatisch nach ' .. Verzoegerung .. ' Sekunden eingesammelt.', {r=0,g=0.8,b=0})
        else
          printToAll('The tricks will now be automatically collected with a delay of ' .. Verzoegerung .. ' seconds.', {r=0,g=0.8,b=0})
        end
      end  
    else
      if Sprache == 'Deutsch' then
        printToColor('Solange Karten auf dem Tisch liegen kann nicht in den automatischen Modus gewechselt werden.',Spieler.color, {r=0.8,g=0,b=0})
      else
        printToColor('You cannot start the automatic mode as long as there cards on the table.',Spieler.color, {r=0.8,g=0,b=0})
      end
    end  
  else
    if text == '!manu' and Spieler.host then
-- Sichtbarmachung der nun benoetigten Buttons
      for i,v in pairs(getSeatedPlayers()) do        
        getObjectFromGUID(guid_schalter[v]).setInvisibleTo({})
      end
      Option = 'manu'    
      if Sprache == 'Deutsch' then
        printToAll('Die Stiche müssen fortan manuell eingesammelt werden.', {r=0,g=0.8,b=0})
      else
        printToAll('From now on, the tricks have to be claimed manually.', {r=0,g=0.8,b=0})
      end
    else
      args = {}
      for i in string.gmatch(text, "%S+") do
        table.insert(args, i)
      end
      if args[1] == "!t" and Spieler.host then
        if Sprache == 'Deutsch' then
          assert(tonumber(args[2]), 'Der Befehl zur Änderung der Zeitverzögerung lautet \"!t x\" (x = Zahlausdruck der Dauer in Sekunden).')
        else
          assert(tonumber(args[2]), 'The command to change the delay is \"!t x\" with x being the number of seconds.')
        end
        if tonumber(args[2]) < 10 then
          Verzoegerung = tonumber(args[2])
          if Sprache == 'Deutsch' then
            printToAll('Die Verzögerungszeit bis die Stiche vom Tisch automatisch eingesammelt werden beträgt nun ' .. args[2] .. ' Sekunden.', {r=0,g=0.8,b=0})
          else
            printToAll('The delay until the tricks are automatically collected from the table is now ' .. args[2] .. ' seconds.', {r=0,g=0.8,b=0})
          end
        end  
      else
        if ErwarteSpielerEingabe == Spieler.color then
          if text == 'blau' or text == '\"blau\"' or text == '\'blau\'' or text == 'blue' or text == '\"blue\"'
          or text == '\'blue\'' then
            Trumpf_Farbe = 'blau'
            ErwarteSpielerEingabe = ''
            if Sprache == 'Deutsch' then
              broadcastToAll(Spieler.steam_name .. ' entscheidet sich für ' .. Trumpf_Farbe .. '.')
            else
              broadcastToAll(Spieler.steam_name .. ' chooses ' .. Trumpf_Farbe .. '.')
            end
          else
            if text == 'rot' or text == '\"rot\"' or text == '\'rot\'' or text == 'red' or text == '\"red\"' or text == '\'red\'' then
              Trumpf_Farbe = 'rot'
              ErwarteSpielerEingabe = ''
              if Sprache == 'Deutsch' then
                broadcastToAll(Spieler.steam_name .. ' entscheidet sich für ' .. Trumpf_Farbe .. '.')
              else
                broadcastToAll(Spieler.steam_name .. ' chooses ' .. Trumpf_Farbe .. '.')
              end
            else
              if text == 'gelb' or text == '\"gelb\"' or text == '\'gelb\'' or text == 'yellow' or text == '\"yellow\"'
              or text == '\'yellow\'' then
                Trumpf_Farbe = 'gelb'
                ErwarteSpielerEingabe = ''
                if Sprache == 'Deutsch' then
                  broadcastToAll(Spieler.steam_name .. ' entscheidet sich für ' .. Trumpf_Farbe .. '.')
                else
                  broadcastToAll(Spieler.steam_name .. ' chooses ' .. Trumpf_Farbe .. '.')
                end
              else
                if text == 'grün' or text == '\"grün\"' or text == '\'grün\'' or text == 'gruen' or text == '\"gruen\"'
                or text == '\'gruen\'' or text == 'green' or text == '\"green\"' or text == '\'green\'' then
                  Trumpf_Farbe = 'grün'
                  ErwarteSpielerEingabe = ''
                  if Sprache == 'Deutsch' then
                    broadcastToAll(Spieler.steam_name .. ' entscheidet sich für ' .. Trumpf_Farbe .. '.')
                  else
                    broadcastToAll(Spieler.steam_name .. ' chooses ' .. Trumpf_Farbe .. '.')
                  end
                end  
              end
            end  
          end  
        end
      end  
    end  
  end 
  
-- aufrufen der Korrigiermodi  
  if Spieler.host then
    if text == '!Stapel_entsperren' or text == '\"!Stapel_entsperren\"' or text == '\'!Stapel_entsperren\'' then
      getObjectFromGUID(kerze_guid).call("StapelEntsperren",Spieler.color) 
    else
      if text == '!Ansage_korrigieren' or text == '\"!Ansage_korrigieren\"' or text == '\'!Ansage_korrigieren\'' then
        getObjectFromGUID(kerze_guid).call("AnsageKorrigieren",Spieler.color) 
      else
        if text == '!Stiche_korrigieren' or text == '\"!Stiche_korrigieren\"' or text == '\'!Stiche_korrigieren\'' then
          getObjectFromGUID(kerze_guid).call("StichZahlKorrigieren",Spieler.color)
        else
          if text == '!Punkte_korrigieren' or text == '\"!Punkte_korrigieren\"' or text == '\'!Punkte_korrigieren\'' then
            getObjectFromGUID(kerze_guid).call("PunkteKorrigieren",Spieler.color)
          else
            if text == '!Spiel_abbrechen' or text == '\"!Spiel_abbrechen\"' or text == '\'!Spiel_abbrechen\'' then
              getObjectFromGUID(kerze_guid).call("RundeAbbrechen",Spieler.color) 
            end
          end
        end
      end
    end
  end
end

function onLoad(saved_data)
-- Einstellungen beim Spielstart
  getObjectFromGUID('aae772').setColorTint('White') -- weisses Kissen muss entfaerbt werden
-- Krakentisch konfigurieren
-- Auslagen vorbereiten
  if getObjectFromGUID('0c8d35') != nil then
    getObjectFromGUID('0c8d35').setState(1)  -- blaue Lade anfangs eingeklappt
  end
  if getObjectFromGUID('665355') != nil then
    getObjectFromGUID('665355').setState(1)  -- weisse Lade anfangs eingeklappt
  end
  if getObjectFromGUID('3c4e81') != nil then
    getObjectFromGUID('3c4e81').setState(1)  -- rote Lade anfangs eingeklappt
  end
  if getObjectFromGUID('661907') != nil then
    getObjectFromGUID('661907').setState(1)  -- gelbe Lade anfangs eingeklappt
  end
  if getObjectFromGUID('88b8d6') != nil then
    getObjectFromGUID('88b8d6').setState(1)  -- tuerkise Lade anfangs eingeklappt
  end
  if getObjectFromGUID('5dd89b') != nil then
    getObjectFromGUID('5dd89b').setState(1)  -- orange Lade anfangs eingeklappt
  end

-- Aufraeumfunktion falls noch Spawn-Objekte vom letzten Spielstand herumschweben
  Aufraeumen()  
  
-- Karten zusammenlegen  
  local objects = getAllObjects()
  for i, object in pairs(objects) do
    if(object.tag == "Card" or object.tag =="Deck") then
      object.setRotation({0,90,180})
      object.setPosition({55.4, 2, -3.8})
      object.setScale({2.68,1,2.68})
    end
  end


-- Eintraege aus Spielstand laden
  laden_erfolgreich = false
  if saved_data ~= "" then
    local loaded_data = JSON.decode(saved_data)
    
    if loaded_data != nil then
      local lTabelle = loaded_data.Tabelle
      if lTabelle != nil then
        if lTabelle["0"] != nil then
          if lTabelle["0"]["0"] != nil then
            laden_erfolgreich = true
-- Eintraege der Tabelle uebernehmen            
            local Spielerzahl = tonumber(lTabelle["0"]["0"])
            glob_Runde_Num = tonumber(lTabelle["0"]["1"])
            
-- Spielerliste aus Datei uebernehmen                          
            if Sprache == 'Deutsch' then
              printToAll('Spielerreihenfolge war zuvor:')
            else
              printToAll('Before the order of players was:')
            end
            for i=1,Spielerzahl do
              if Sprache == 'Deutsch' then
                printToAll('Spieler ' .. i .. ': ' .. lTabelle[tostring(i)]["0"])
              else
                printToAll('Player ' .. i .. ': ' .. lTabelle[tostring(i)]["0"])
              end
              local id = "P" .. i
              UI.setAttribute(id, "text", lTabelle[tostring(i)][tostring("0")]) 

-- Tabelleneintraege uebernehmen
              for j=1,glob_Runde_Num do
                local id = "R" .. j .. "P" .. i .. "_Punkte"
                UI.setAttribute(id, "text", lTabelle[tostring(2*i-1)][tostring(j)]) 
                id = "R" .. j .. "P" .. i .. "_Ansage"
                UI.setAttribute(id, "text", lTabelle[tostring(2*i)][tostring(j)]) 
              end
            end
            Modus = 'Auswerten'
            erste_Runde_seit_Laden = true
          end  
        end
      end
    end
  end
  
  if not laden_erfolgreich then
    if Sprache == 'Deutsch' then
      printToAll('Beginne ein neues Spiel')
      printToAll('Einige Optionen können über den Chat eingestellt werden. Für eine Auflistung \"!hilfe\" eingeben', {r=0.8,g=0.8,b=0.8})
      printToAll('To change the language to English, enter \"!English\"', {r=0.8,g=0.8,b=0.8})
    else
      printToAll('Start a new game')
      printToAll('Some options can be set via the chat. For a listing enter \"!help\".', {r=0.8,g=0.8,b=0.8})
    end
    Modus = 'Starten'
  end
  
  


  if Modus == 'Starten' then
    local btn_pmt = {
      click_function = "neueRunde",
      function_owner = self,
      position = { 0, 11, 3.3},
      color = {0.204, 0.122, 0.078},
      font_color = {1, 1, 1},
      width = 4960,
      height = 1600,
      font_size = 800,
    }
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "neues Spiel"
    btn_pmt['tooltip'] = "neues Spiel beginnen"
  else
    btn_pmt['label'] = "new game"
    btn_pmt['tooltip'] = "start a new game"
  end
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)
  
  btn_pmt = {
    click_function = "neueRunde",
    function_owner = self,
    color = {0.204, 0.122, 0.078},
    font_color = {1, 1, 1},
    width = 4960,
    height = 1600,
    font_size = 800,
    rotation = {0, 180, 0},
    position = { 0, 11, -4.2}
  } 
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "neues Spiel"
    btn_pmt['tooltip'] = "neues Spiel beginnen"
  else
    btn_pmt['label'] = "new game"
    btn_pmt['tooltip'] = "start a new game"
  end
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)   
  else
    if Modus == 'Auswerten' then
      UI.setAttribute("Frame", "visibility", "Black|Grey|Blue|White|Red|Teal|Yellow|Orange")
      local btn_pmt = {
      click_function = "neueRunde",
      function_owner = self,
      position = { 0, 11, 3.3},
      color = {0.204, 0.122, 0.078},
      font_color = {1, 1, 1},
      width = 4960,
      height = 1600,
      font_size = 800,
    }
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "nächste Runde"
    btn_pmt['tooltip'] = "nächste Runde beginnen"
  else
    btn_pmt['label'] = "next round"
    btn_pmt['tooltip'] = "start next round"
  end
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)
  
  btn_pmt = {
    click_function = "neueRunde",
    function_owner = self,
    color = {0.204, 0.122, 0.078},
    font_color = {1, 1, 1},
    width = 4960,
    height = 1600,
    font_size = 800,
    rotation = {0, 180, 0},
    position = { 0, 11, -4.2}
  }  
  if Sprache == 'Deutsch' then
    btn_pmt['label'] = "nächste Runde"
    btn_pmt['tooltip'] = "nächste Runde beginnen"
  else
    btn_pmt['label'] = "next round"
    btn_pmt['tooltip'] = "start next round"
  end
  getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)   
   end   
  end 
end

function oeffneAuslagen(Spielerliste)
  for i,v in pairs(Spielerliste) do
    if getObjectFromGUID('390971') != nil and v == 'Blue' then
      getObjectFromGUID('390971').setState(2)  -- oeffne blaue Lade
      Anmeldung(v)
    end
    if getObjectFromGUID('b1ab11') != nil  and v == 'White' then
      getObjectFromGUID('b1ab11').setState(2)  -- oeffne weisse Lade
      Anmeldung(v)
    end
    if getObjectFromGUID('e2b080') != nil  and v == 'Red' then
      getObjectFromGUID('e2b080').setState(2)  -- oeffne rote Lade
      Anmeldung(v)
    end
    if getObjectFromGUID('3dcbdd') != nil  and v == 'Yellow' then
      getObjectFromGUID('3dcbdd').setState(2)  -- oeffne gelbe Lade
      Anmeldung(v)
    end
    if getObjectFromGUID('2fa11f') != nil  and v == 'Teal' then
      getObjectFromGUID('2fa11f').setState(2)  -- oeffne tuerkise Lade
      Anmeldung(v)
    end
    if getObjectFromGUID('7d257b') != nil  and v == 'Orange' then
      getObjectFromGUID('7d257b').setState(2)  -- oeffne orange Lade
      Anmeldung(v)
    end  
  end
end

function takeAndRename()
  local takeFromTop = true 
  local flipCards = false
  local frameWait = 1 
  local objects = getAllObjects()
  local deck = {}
  for _, object in pairs(objects) do
    if(object.tag =="Deck") then
      deck = object
    end  
  end
  local nameKey = 1
  local cardNames = { 'N', 'N', 'Z', 'Z', 'N', 'Z', 'N', 'Z', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'grün', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'rot', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'blau', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb', 'gelb'}

  local cardDescriptions = { '', '', '', '', '', '', '', '', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13'}
  local heightStep = 3/((#deck.getObjects() < #cardNames) and #deck.getObjects() or #cardNames)
  local numberOfCards = deck.getObjects()
  
  watchCards = false
  while deck ~= nil and cardNames[nameKey] ~= nil do
    local targetPos = deck.positionToWorld({5.8, 0, 0})
    targetPos.y = targetPos.y + (nameKey*heightStep)
    local newCard = deck.takeObject({ position = targetPos, top = takeFromTop, flip = flipCards })
    if nameKey == #numberOfCards then
      watchCards = true
      for i=1,5,1 do coroutine.yield(0) end
    end
    newCard.setName(cardNames[nameKey])
    newCard.setDescription(cardDescriptions[nameKey])
    nameKey = nameKey+1
    for i=1,frameWait,1 do coroutine.yield(0) end
  end
  watchCards = false
  neues_Deck_bereit = true
  return 1
end


function FuegeDeckEin()
  spawnparams = {
    type = 'DeckCustom',
    position = {55.4, 2, -3.8},
    rotation = {0,90,180},
    scale = {2.68,1,2.68}
  }
  object = spawnObject(spawnparams)
  params = {
    face = "http://cloud-3.steamusercontent.com/ugc/438361316028824119/E751B51DC528E91EA3724CD5F23C0891D21D0DBB/",
    unique_back = false,
    back = "http://cloud-3.steamusercontent.com/ugc/438361316028829836/84878FE0709BC7AA3061E6AEB93296CEC18E634D/",
    width = 10,
    height = 7,
    number = 60,
  }
  object.setCustomObject(params)
  
-- beschriften der Karten
  startLuaCoroutine(Global, "Warte")
  startLuaCoroutine(Global, "takeAndRename")   
end

function neueRunde()
  local cards = {}
  local objects = {}
  local stapel = {}
  local zaehler = 0 -- zaehlt die je Spieler ausgegebenen Karten
  local Fehler = false -- ist im Verlauf des Kartenausgebens ein Fehler aufgetreten?
  local Spielerliste = getSeatedPlayers()
  local Geber = ''
  local Deck_ok = true

-- muessen mindestens drei Spieler mitspielen
-- if #Spielerliste > 2 then  (deaktiviert)

  
-- Buttons vom Tisch entfernen
  for i, k in ipairs(getObjectFromGUID(tischplatte_guid).getButtons()) do
    for j = 0, (i-1) do
      getObjectFromGUID(tischplatte_guid).removeButton(j)  -- doppelt sicheres loeschen der Buttons?? nach Bug bei einigen Spieler mit
    end                                                    -- removeButton(k.index)  
  end                                                      -- sodass removeButton(0) alle beseitigen sollte
  
-- Korrekturmodi deaktivieren
  getObjectFromGUID(kerze_guid).call("KorrekturmodiDeaktivieren")
  
  if (glob_Runde_Num) != 60 / #Spielerliste and HaendeLeer(Spielerliste) then   -- Spieler duerfen keine Karten mehr auf der Hand haben 

    oeffneAuslagen(Spielerliste)

-- in der ersten Runde muss der Startspieler erst bestimmt werden  
    if glob_Startspieler == nil then
      if glob_Startspieler == '' or Player[glob_Startspieler].steam_name == nil then -- letzteres kann passieren, wenn beim Neuladen andere Farben
        glob_Startspieler =   getObjectFromGUID(kerze_guid).call("KerzeStehtBei",Spielerliste) -- gewaehlt werden
        if glob_Startspieler == '' or Player[glob_Startspieler].steam_name == nil then
          for _,v in pairs(getSeatedPlayers()) do
            if Player[v].host then
              glob_Startspieler = v  -- sonst faengt Spielleiter an
            end
          end    
        end  
      end  
    else
      if glob_Startspieler == '' or Player[glob_Startspieler].steam_name == nil then -- analog zu Startspieler == nil
        if glob_Startspieler == '' or Player[glob_Startspieler].steam_name == nil then -- letzteres kann passieren, wenn beim Neuladen andere Farben
          glob_Startspieler =   getObjectFromGUID(kerze_guid).call("KerzeStehtBei",Spielerliste) -- gewaehlt werden
          if glob_Startspieler == '' or Player[glob_Startspieler].steam_name == nil then
            for _,v in pairs(getSeatedPlayers()) do
              if Player[v].host then
                glob_Startspieler = v  -- sonst faengt Spielleiter an
              end
            end    
          end  
        end
      else
-- in jeder weiteren Runde ist dies der naechst platzierte Spieler    
        Geber = glob_Startspieler
        glob_Startspieler = naechsterSpieler(glob_Startspieler)
      end  
    end  
   
    local KartenSammeln = function() 
--Karten zusammenlegen
      stapel.interactable = true
      objects = getAllObjects()
      for _, object in pairs(objects) do
        if(object.tag == "Card" or object.tag =="Deck") then
          object.setRotation({0,90,180})
          object.setPosition({55.4, 2, -3.8})
          object.setScale({2.68,1,2.68})
          object.interactable = true
        end
      end
      startLuaCoroutine(Global, "Warte")
    
-- bestimme Stapel    
      objects = getAllObjects()
      for _, object in pairs(objects) do
        if(object.tag =="Deck") then
          stapel = object
        end  
      end
      for _, obj in pairs(objects) do
        if(obj.tag =="Card") then
          stapel = group({stapel,obj})[1]
        end  
      end
    
      startLuaCoroutine(Global, "Warte")
    end
    KartenSammeln()
    
-- Funktion muss wahr sein um Funktion KartenAusgeben auszufuehren
    local StapelKomplett = function()
      
      
      if stapel.getQuantity() == -1 then
        objects = getAllObjects()
        for _, object in pairs(objects) do
          if(object.tag =="Deck") then
            stapel = object
          end  
        end
      else
        if stapel.getQuantity() < 60 then
          objects = getAllObjects()
          for _, object in pairs(objects) do
            if(object.tag =="Deck") then
              stapel = object 
            end  
          end  
        else
-- Decks, die sich im Deck stapel befinden, aufloesen und deren Elemente zu stapel hinzufuegen
          if stapel.getQuantity() > 60 then
            for _, object in pairs(stapel.getObjects()) do
              if object.tag == "Deck" then
                for _, element in object do
                  stapel.putObject(element)
                end
                object.destruct()
              end
            end
 
-- gedoppelte Karten aus stapel loeschen
            local KartenListe = {}
            for _, object in pairs(stapel.getObjects()) do
              if table.contains(KartenListe, object) then
                object.destruct()
              else
                table.insert(KartenListe, object)
              end
            end
          end
        end
      end    

      return stapel.getQuantity() == 60
    end
    
-- Funktion KartenAusgeben wird warten bis obige Funktion wahr ist
    local KartenAusgeben = function()
      if glob_Runde_Num < 60 / #Spielerliste then 
        stapel.shuffle()
-- Rundenzaehler dieser Skriptliste erhoehen           
        glob_Runde_Num = glob_Runde_Num + 1
-- Karten an Spieler ausgeben        
        for _,k in pairs(Spielerliste) do
          Wait.frames(function()
            stapel.deal(glob_Runde_Num,k)
            zaehler=glob_Runde_Num 
          end, 20)
        end
        Wait.frames(function() stapel.interactable = false end, 240)

-- trage fuer automatischen Modus ein welcher Spieler welche Karten haelt
        for _,pl in pairs(getSeatedPlayers()) do
          Wait.frames(function() Karten[pl] = Player[pl].getHandObjects() end, 50)  	  
        end
      else
        Endauswertung()
      end
    end
      
-- Funktion wird ausgefuehrt falls StapelKomplett zu lange falsch ist
    local KartenFehlen = function()
      if Sprache == 'Deutsch' then
        print('Anzahl der Karten im Deck stimmt nicht. Deck wird gelöscht und ein neues eingefügt.')
      else
        print('Number of cards in the deck is not correct. Deck is deleted and a new one is inserted.')
      end
      Deck_ok = false
      neues_Deck_bereit = false
-- loesche Deck
      local objects = getAllObjects()
      for _, object in pairs(objects) do
        if(object.tag =="Deck") or (object.tag=="Card") then
          object.destruct()
        end  
      end
      
      Wait.frames(function()
-- fuege neues Deck ein
        FuegeDeckEin()
-- bestimme neuen Stapel
        Wait.frames(function()
          stapel = {}
          objects = getAllObjects()
          for _, object in pairs(objects) do
            if(object.tag =="Deck") then
              stapel = object
            end  
          end
          for _, obj in pairs(objects) do
            if(obj.tag =="Card") then
              stapel = group({stapel,obj})[1]
            end  
          end      
-- Ende von bestimme neuen Stapel
-- jetzt noch mischen
          Wait.frames(function() stapel.shuffle() end,60)
        end, 200)
      end, 10)
      
      local WeiterMitAusgabe = function()
        
        objects = getAllObjects()
        for _, object in pairs(objects) do
          if(object.tag =="Deck") then
            stapel = object 
          end  
        end  
        startLuaCoroutine(Global, "Warte")
        KartenAusgeben()  
      end
      Wait.Condition(||Wait.frames(WeiterMitAusgabe,200), function() return neues_Deck_bereit end)
    end

-- wartet maximal zwei Sekunden bis StapelKomplett == true
-- und fuehrt dann KartenAusgeben aus,
-- sonst wird KartenFehlen ausgeführt
    Wait.frames(|| Wait.condition(KartenAusgeben, StapelKomplett,2,KartenFehlen), 10) -- vor der Abfrage nochmals 10 Frames warten

-- ggf. sortieren              
    local KartenSortieren = function()
      for _,p in pairs(getSeatedPlayers()) do
        if Sortieren[p] then
          HandSortieren(p)
        end    
      end  
    end
    Wait.frames(KartenSortieren, 40)

  
-- Trumpf aufdecken nachdem alle Spieler alle Karten haben  
-- wieder mit Verzoegerungsfunktion
-- hat jeder Spieler die erforderliche Zahl an Karten auf der Hand?
    local AlleKartenAufHand = function()
      return (zaehler >= glob_Runde_Num) and (zaehler > 0)
    end 
  
-- falls dies nach 10 Sekunden nicht erreicht wird
-- Ausgabe: Fehler beim Geben
    local FehlerBeimGeben = function()
      Fehler = true
      if Sprache == 'Deutsch' then
        printToAll('Beim Geben ist ein mysteriöser Fehler aufgetreten. Oder dauert das zu lang?', {r=0.8,g=0,b=0})
      else
        printToAll('Something went wrong while handing out the cards', {r=0.8,g=0,b=0})
      end
    end  
  
  
    local TrumpfLegen = function ()       
      takeParameter = {
        position = {x = 55.4, y = 2, z = 4},
        rotation = {0,90,180},
        flip = true
      }
      local aufgedeckte_Karte = stapel.getObjects()[1].name
      stapel.takeObject(takeParameter)
-- restlichen Stapel verstecken, sodass niemand die verbleibenden Karten einsehen kann
--  stapel.setHiddenFrom(Spielerliste)
      stapel.attachHider("hide", true, {})
-- hide funktioniert scheinbar nicht, daher keine Interaktion möglich
      Wait.frames(function() stapel.interactable = false end, 200)
      if aufgedeckte_Karte != 'N' and aufgedeckte_Karte != 'Z' then
        if Sprache == 'Deutsch' then
          broadcastToAll('Runde ' .. glob_Runde_Num .. ': Trumpf ist ' .. aufgedeckte_Karte .. ', ' .. Player[glob_Startspieler].steam_name .. ' beginnt.')  
        else
          if aufgedeckte_Karte == 'blau' then
            aufgedeckte_Karte = 'blue'
          else
            if aufgedeckte_Karte == 'rot' then
              aufgedeckte_Karte = 'red'
            else
              if aufgedeckte_Karte == 'grün' then
                aufgedeckte_Karte = 'green'
              else
                if aufgedeckte_Karte == 'gelb' then
                aufgedeckte_Karte = 'yellow'
                end
              end
            end
          end
          broadcastToAll('Round ' .. glob_Runde_Num .. ': Color of trump is ' .. aufgedeckte_Karte .. ', ' .. Player[glob_Startspieler].steam_name .. ' starts.')  
        end
        Trumpf_Farbe = aufgedeckte_Karte
      else
        if aufgedeckte_Karte == 'Z' then
-- wenn Zauberer aufgedeckt wird, darf Geber Trumpf auswaehlen        
          if Geber == '' then
-- falls Geber nicht bekannt ist, muss er rueckwaerts von Startspieler aus bestimmt werden  
            Geber = glob_Startspieler        
            for i,v in ipairs(getSeatedPlayers()) do
              if i != 1 then
                Geber = naechsterSpieler(glob_Startspieler)
              end 
            end
          end  
          if Sprache == 'Deutsch' then
            broadcastToAll('Runde ' .. glob_Runde_Num .. ': ' .. Player[Geber].steam_name .. ' darf die Trumpffarbe wählen, ' .. Player[glob_Startspieler].steam_name .. ' beginnt.')
          else
            broadcastToAll('Round ' .. glob_Runde_Num .. ': ' .. Player[Geber].steam_name .. ' can select the color of trump, ' .. Player[glob_Startspieler].steam_name .. ' will start.')
          end
          Trumpf_Farbe = 'Z'
          ErwarteSpielerEingabe = Geber
-- Nachricht an Geber            
          if Sprache == 'Deutsch' then
            Meldung = function () broadcastToColor('Bitte Trumpffarbe wählen: \"blau\", \"gelb\", \"rot\" oder \"grün\" bzw. \"gruen\" in den Chat eingeben',Geber) end
          else
            Meldung = function () broadcastToColor('Please select the color of trump: Enter \"blue\", \"yellow\", \"red\" oder \"green\" into the chat',Geber) end
          end
          Meldung()
          id_wt4 = Wait.time(Meldung, 5)
          id_wt5 = Wait.time(Meldung, 10)
          id_wt6 = Wait.time(Meldung, 15)
        else
          if Sprache == 'Deutsch' then
            broadcastToAll('Runde ' .. glob_Runde_Num .. ': Diesmal gibt es keine Trumpffarbe, ' .. Player[glob_Startspieler].steam_name .. ' beginnt.')
          else
            broadcastToAll('Round ' .. glob_Runde_Num .. ': This time, there is no trump, ' .. Player[glob_Startspieler].steam_name .. ' will start.')
          end
          Trumpf_Farbe = ''
        end  
      end
-- aktiviert die Funktion zum Taetigen von Ansagen
      if (not Fehler) then
-- warte auf Trumpf-Eingabe falls Z als Trumpfkarte gezogen wurde      
        local Nach_Warten = function()
          Trumpf_Farbe=''
          if Sprache == 'Deutsch' then
            broadcastToAll('keine Trumpffarbe ausgewählt')
          else
            broadcastToAll('No color of trump has been chosen')
          end
          ErwarteSpielerEingabe = '' StarteAnsagen() end
        local Fertig_tf = function()
          if id_wt4 != nil then
            Wait.stop(id_wt4)
          end
          if id_wt5 != nil then
            Wait.stop(id_wt5)
          end  
          if id_wt6 != nil then  
            Wait.stop(id_wt6)
          end  
          StarteAnsagen()
        end  
        Wait.condition(Fertig_tf, function() return Trumpf_Farbe != 'Z' end,20,Nach_Warten)
      end         
    end
    
  
    if ((glob_Runde_Num + 1) != 60 / #Spielerliste) and (not Fehler) then -- scheinbar ist der Rundenzaehler bis
      Wait.condition(TrumpfLegen, AlleKartenAufHand,30,FehlerBeimGeben)              -- zu dieser Stelle noch nicht erhoeht worden
    else
      if Sprache == 'Deutsch' then
        broadcastToAll('Die letzte Runde beginnt: Es gibt keine Trumpffarbe, ' .. Player[glob_Startspieler].steam_name .. ' spielt aus.')  
      else
        broadcastToAll('The last round is about to begin: There will be no trump, ' .. Player[glob_Startspieler].steam_name .. ' starts.')  
      end
      Trumpf_Farbe = ''
      StarteAnsagen()
    end      
    

  else
    if (glob_Runde_Num == (60 / #Spielerliste)) then
      Endauswertung()
    else
      if Sprache == 'Deutsch' then
        printToAll('Die neue Runde kann erst begonnen werden, wenn niemand mehr Karten auf der Hand hält.', {r=0.8,g=0,b=0})
      else
        printToAll('The next round can only start when there are no cards in the players\' hand zones.', {r=0.8,g=0,b=0})
      end
-- Buttons wieder anzeigen
      local btn_pmt = {
        click_function = "neueRunde",
        function_owner = self,
        position = { 0, 11, 3.3},
        color = {0.204, 0.122, 0.078},
        font_color = {1, 1, 1},
        width = 4960,
        height = 1600,
        font_size = 800,
      }
      if Sprache == 'Deutsch' then
        btn_pmt['label'] = "nächste Runde"
        btn_pmt['tooltip'] = "nächste Runde beginnen"
      else
        btn_pmt['label'] = "next round"
        btn_pmt['tooltip'] = "start next round"
      end
      getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)
  
      btn_pmt = {
        click_function = "neueRunde",
        function_owner = self,
        color = {0.204, 0.122, 0.078},
        font_color = {1, 1, 1},
        width = 4960,
        height = 1600,
        font_size = 800,
        rotation = {0, 180, 0},
        position = { 0, 11, -4.2}
      } 
      if Sprache == 'Deutsch' then
        btn_pmt['label'] = "nächste Runde"
        btn_pmt['tooltip'] = "nächste Runde beginnen"
      else
        btn_pmt['label'] = "next round"
        btn_pmt['tooltip'] = "start next round"
      end
      getObjectFromGUID(tischplatte_guid).createButton(btn_pmt)  
    end
  end 

-- falls weniger als drei Spieler im Spiel sind:
--else  (deaktiviert)
--  printToAll('Es müssen mindestens drei Spieler teilnehmen.',, {r=0.8,g=0,b=0})     
-- end  
    
end 


function WechselUI(player)
-- Standardparamter von UI-Funktionen
-- player = Spieler, der UI-Element betaetigt hat

  local UIvisib = UI.getAttribute("Frame", "visibility") -- lese Sichtbarkeit aus
  local farbe = ""
  
  if player.color != nil then -- finde heraus ob farbe = player oder farbe = player.color sein muss
    farbe = player.color
  else
    farbe = player
  end

  if UIvisib == nil or UIvisib == "empty" then  -- UI ist unsichtbar fuer alle
    -- "or UIvisib == "empty"" ist eine Korrektur durch mineslime
    UI.setAttribute("Frame", "visibility", farbe) -- setze es als sichtbar fuer player
  else
    if string.find(UIvisib, farbe) == nil then  -- UI ist sichtbar, aber nicht fuer player
      UI.setAttribute("Frame", "visibility", UIvisib .. "|" .. farbe) -- fuege player.color zur Sichtbarkeitsliste hinzu,
      -- "|" ist Listentrenner
    else -- UI ist sichtbar fuer player
      if UIvisib == farbe then -- UI ist sichtbar fuer player, aber nicht fuer andere
        UI.setAttribute("Frame", "visibility", "empty") -- setze es als unsichtbar fuer alle
      else
        UIvisib = string.gsub(UIvisib, farbe, "") -- loesche player.color aus Sichtbarkeitsliste
        UIvisib = string.gsub(UIvisib, "||", "|") -- loesche nun ueberschuessiges Trennungssymbol
        if string.sub(UIvisib, -1) == "|" then -- falls player.color an letzter Stelle stand
            UIvisib = string.sub(UIvisib, 1, -2)
        end
        -- Korrektur durch mineslime:
        if string.sub(UIvisib, 1, 1) == "|" then -- falls player.color an erster Stelle stand
            UIvisib = string.sub(UIvisib, 2)
        end
        UI.setAttribute("Frame", "visibility", UIvisib) -- aktualisiere die Sichtbarkeitsliste
      end
    end
  end
end


function onSave()
-- beim Speichern des Spiels
-- Tabelleninhalte auslesen und in Datei schreiben
  local spTabelle = {}        -- Inhalte UI-Tabelle sollen in diese eingetragen werden
  if glob_Runde_Num >= 1 then   -- es macht keinen Sinn etwas vor der ersten Runde zu speichern
    
    spTabelle["0"] = {}
    spTabelle["0"]["0"] = #getSeatedPlayers()      -- Informationen ueber Spielstand
    if Modus == 'Auswerten' then
      spTabelle["0"]["1"] = glob_Runde_Num
    else
      spTabelle["0"]["1"] = glob_Runde_Num - 1     -- da aktuelle Runde abgebrochen wird, muss Rundenzaehler wieder um eins reduziert werden
    end  
    
    for i,_ in ipairs(getSeatedPlayers()) do
      local k = 2*i-1
      spTabelle[tostring(k)] = {}        -- eine Spalte fuer Punkte
      k = k + 1
      spTabelle[tostring(k)]   = {}      -- eine Spalte fuer Ansagen
      
      local id = "P" .. i
      spTabelle[tostring(i)]["0"] = UI.getAttributes(id).text -- uebernehme Namen in Spielreihenfolge
      
      for j = 1, glob_Runde_Num do
        id = "R" .. j .. "P" .. i .. "_Punkte"
        k = 2*i-1
        spTabelle[tostring(k)][tostring(j)] = UI.getAttributes(id).text   -- uebernehme Punkte
        id = "R" .. j .. "P" .. i .. "_Ansage"
        k = k + 1
        spTabelle[tostring(k)][tostring(j)] = UI.getAttributes(id).text   -- uebernehme Ansage
      end
    end
  end
  
  saved_data = JSON.encode({["Tabelle"]= tableCullNumericIndexes(spTabelle)})  -- Tabelle mit allen Werten in JSON string kodieren
  return saved_data                                             -- vorsichtshalber nochmals auf numerische Indices pruefen
end

function ClosePanel(player)
  WechselUI(player)
end

function tableCullNumericIndexes(t)
    for i in pairs(t) do
        if type(i) == "number" then
            table.remove(t, i)
            return tableCullNumericIndexes(t)
        end
    end
    return t
end