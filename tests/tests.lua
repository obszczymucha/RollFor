local function descending( l, r )
    return l[ "similarity" ] > r[ "similarity" ]
end

local function improvedDescending( l, r )
    return l[ "levenshtein" ] < r[ "levenshtein"] or l[ "levenshtein" ] == r[ "levenshtein" ] and l[ "similarity" ] > r[ "similarity" ]
end

local function ascending( l, r )
    return l[ "similarity" ] < r[ "similarity" ]
end

function StringSimilarity( s1, s2 )
    local n = string.len( s1 )
    local m = string.len( s2 )
    local ssnc = 0

    if n > m then
        s1, s2 = s2, s1
        n, m = m, n
    end

    for i = n, 1, -1 do
        if i <= string.len( s1 ) then
            for j = 1, n - i + 1, 1 do
                local pattern = string.sub( s1, j, j + i - 1 )
                if string.len( pattern ) == 0 then break end
                local foundAt = string.find( s2, pattern )

                if foundAt ~= nil then
                    ssnc = ssnc + ( 2 * i ) ^ 2
                    s1 = string.sub( s1, 0, j - 1 ) .. string.sub( s1, j + i )
                    s2 = string.sub( s2, 0, foundAt - 1 ) .. string.sub( s2, foundAt + i )
                    break
                end
            end
        end
    end

    return ( ssnc / ( ( n + m ) ^ 2 ) ) ^ ( 1 / 2 )
end

local function Levenshtein( s1, s2 )
    local len1 = #s1
    local len2 = #s2
    local matrix = {}
    local cost = 1
    local min = math.min;

    -- quick cut-offs to save time
    if ( len1 == 0 ) then
        return len2
    elseif ( len2 == 0 ) then
        return len1
    elseif ( s1 == s2 ) then
        return 0
    end

    -- initialise the base matrix values
    for i = 0, len1, 1 do
        matrix[ i ] = {}
        matrix[ i ][ 0 ] = i
    end
    for j = 0, len2, 1 do
        matrix[ 0 ][ j ] = j
    end

    -- actual Levenshtein algorithm
    for i = 1, len1, 1 do
        for j = 1, len2, 1 do
            if ( s1:byte( i ) == s2:byte( j ) ) then
                cost = 0
            end

            matrix[ i ][ j ] = min( matrix[ i - 1 ][ j ] + 1, matrix[ i ][ j - 1 ] + 1, matrix[ i - 1 ][ j - 1 ] + cost )
        end
    end

    -- return the last value - this is the Levenshtein distance
    return matrix[ len1 ][ len2 ]
end

local function min(a, b, c)
	return math.min(math.min(a, b), c)
end

-- Creates a 2D matrix
local function matrix(row,col)
  local m = {}
  for i = 1,row do m[i] = {}
    for j = 1,col do m[i][j] = 0 end
  end
  return m
end

-- Calculates the Levenshtein distance between two strings
local function lev_iter_based(strA,strB)
  local M = matrix(#strA+1,#strB+1)
  local i,j,cost
  local row,col = #M,#M[1]
  for i = 1,row do M[i][1] = i-1 end
  for j = 1,col do M[1][j] = j-1 end
  for i = 2,row do
    for j = 2,col do
      if (strA:sub(i-1,i-1) == strB:sub(j-1,j-1)) then cost = 0
      else cost = 1
      end
    M[i][j] = min(M[i-1][j]+1,M[i][j-1]+1,M[i-1][j-1]+cost)
    end
  end
  return M[row][col]
end

local function lev_recursive_based(strA, strB, s, t)
    s, t = s or #strA, t or #strB
    if s == 0 then return t end
    if t == 0 then return s end
    local cost = strA:sub(s,s) == strB:sub(t,t) and 0 or 1
    return min(
      lev_recursive_based(strA, strB, s - 1, t) + 1,
      lev_recursive_based(strA, strB, s, t - 1) + 1,
      lev_recursive_based(strA, strB, s - 1, t - 1) + cost
    )
  end

local function GetSimilarityPredictions( playersInGroupWhoDidNotSoftRes, playersNotInGroupWhoSoftRessed, sort )
    local results = {}

    for _, player in pairs( playersInGroupWhoDidNotSoftRes ) do
        local predictions = {}

        for _, candidate in pairs( playersNotInGroupWhoSoftRessed ) do
            local prediction = { [ "candidate" ] = candidate, [ "similarity" ] = StringSimilarity( player, candidate ), [ "levenshtein" ] = lev_iter_based( player, candidate ) } 
            table.insert( predictions, prediction )
        end

        table.sort( predictions, sort )
        results[ player ] = predictions
    end

    return results
end

local function endsWith( str, ending )
    return ending == "" or str:sub( -#ending ) == ending
 end

function formatPercent( value )
    local result = string.format( "%.2f", value * 100 )

    if endsWith( result, "0" ) then
        result = string.sub( result, 0, string.len( result ) - 1 )
    end

    if endsWith( result, "0" ) then
        result = string.sub( result, 0, string.len( result ) - 1 )
    end

    if endsWith( result, "." ) then
        result = string.sub( result, 0, string.len( result ) - 1 )
    end

    return string.format( "%s%%", result )
end

function AssignPredictions( predictions, threshold )
    local results = {}

    for player, prediction in pairs( predictions ) do
        local topCandidate = prediction[ 1 ]

        if topCandidate[ "similarity" ] >= threshold then
            results[ player ] = { [ "override" ] = topCandidate[ "candidate" ], [ "similarity" ] = formatPercent( topCandidate[ "similarity" ] ) }
        end
    end

    return results
end

local function test( testName, f )
    if not f() then
        error( string.format( "%s FAILED", testName ) )
    else
        print( string.format( "%s PASSED", testName ) )
    end
end

local function eq( l, r )
    if tostring( l ) == tostring( r ) then return true end

    print( string.format( "Expected: %s but was: %s", r, l ) )
    return false
end

function CountElements( t, f )
    local result = 0
    
    for _, v in pairs( t ) do
        if f and f( v ) or not f then
            result = result + 1
        end
    end

    return result
end

test( "Should three entries", function() 
    local a = { "Angelababee", "Ébonymaw", "Ásbern" }
    local b = { "Ebonyclaw", "Asbern", "Agenlababee", "Ebonymaw", "Assbern" }

    local results = GetSimilarityPredictions( a, b, descending )

    return CountElements( results ) == 3
end )

test( "Should order predictions from highest to lowest for Angelababee", function()
    local a = { "Angelababee", "Ébonymaw", "Ásbern" }
    local b = { "Ebonyclaw", "Asbern", "Agenlababee", "Ebonymaw", "Assbern" }
    
    local results = GetSimilarityPredictions( a, b, descending )
    
    local result = results[ "Angelababee" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]
    local p3 = result[ 3 ]
    local p4 = result[ 4 ]
    local p5 = result[ 5 ]

    return
        eq( p1[ "candidate" ], "Agenlababee" ) and eq( p1[ "similarity" ], 0.738548945876 ) and
        eq( p2[ "candidate" ], "Asbern" ) and eq( p2[ "similarity" ], 0.26306682088233 ) and
        eq( p3[ "candidate" ], "Assbern" ) and eq( p3[ "similarity" ], 0.24845199749998 ) and
        eq( p4[ "candidate" ], "Ebonyclaw" ) and eq( p4[ "similarity" ], 0.22360679774998 ) and
        eq( p5[ "candidate" ], "Ebonymaw" ) and eq( p5[ "similarity" ], 0.10526315789474 )
end )

test( "Should order predictions from highest to lowest for Ébonymaw", function()
    local a = { "Ébonymaw" }
    local b = { "Ebonynaw", "Ebonymaw", "Ébonynaw", "Ébonymaws", "Ébonyma" }
    
    local results = GetSimilarityPredictions( a, b, descending )
    local result = results[ "Ébonymaw" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]
    local p3 = result[ 3 ]
    local p4 = result[ 4 ]
    local p5 = result[ 5 ]

    return
        eq( p1[ "candidate" ], "Ébonymaws" ) and eq( p1[ "similarity" ], 0.94736842105263 ) and
        eq( p2[ "candidate" ], "Ébonyma" ) and eq( p2[ "similarity" ], 0.94117647058824 ) and
        eq( p3[ "candidate" ], "Ebonymaw" ) and eq( p3[ "similarity" ], 0.82352941176471 ) and
        eq( p4[ "candidate" ], "Ébonynaw" ) and eq( p4[ "similarity" ], 0.74535599249993 ) and
        eq( p5[ "candidate" ], "Ebonynaw" ) and eq( p5[ "similarity" ], 0.58823529411765 )
end )

test( "Should order predictions from highest to lowest for Ebonymaw", function()
    local a = { "Ebonymaw" }
    local b = { "Ebonynaw", "Ebonymaw", "Ébonynaw", "Ébonymaws", "Ébonyma" }
    
    local results = GetSimilarityPredictions( a, b, descending )
    local result = results[ "Ebonymaw" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]
    local p3 = result[ 3 ]
    local p4 = result[ 4 ]
    local p5 = result[ 5 ]

    return
        eq( p1[ "candidate" ], "Ebonymaw" ) and eq( p1[ "similarity" ], 1.0 ) and
        eq( p2[ "candidate" ], "Ébonymaws" ) and eq( p2[ "similarity" ], 0.77777777777778 ) and
        eq( p3[ "candidate" ], "Ébonyma" ) and eq( p3[ "similarity" ], 0.75 ) and
        eq( p4[ "candidate" ], "Ebonynaw" ) and eq( p4[ "similarity" ], 0.72886898685566 ) and
        eq( p5[ "candidate" ], "Ébonynaw" ) and eq( p5[ "similarity" ], 0.58823529411765 )
end )

test( "Should order predictions from highest to lowest for Ebonymaw", function()
    local a = { "Ebonymaw" }
    local b = { "Ebonynaw", "Ebonymaw", "Ébonynaw", "Ébonymaws", "Ébonyma" }
    
    local results = GetSimilarityPredictions( a, b, improvedDescending )
    local result = results[ "Ebonymaw" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]
    local p3 = result[ 3 ]
    local p4 = result[ 4 ]
    local p5 = result[ 5 ]

    return
        eq( p1[ "candidate" ], "Ebonymaw" ) and eq( p1[ "similarity" ], 1.0 ) and eq( p1[ "levenshtein" ], 0 ) and
        eq( p2[ "candidate" ], "Ebonynaw" ) and eq( p2[ "similarity" ], 0.72886898685566 ) and eq( p2[ "levenshtein" ], 0 ) and
        eq( p3[ "candidate" ], "Ébonyma" ) and eq( p3[ "similarity" ], 0.75 ) and eq( p3[ "levenshtein" ], 2 ) and
        eq( p4[ "candidate" ], "Ébonynaw" ) and eq( p4[ "similarity" ], 0.58823529411765 ) and eq( p4[ "levenshtein" ], 2 ) and
        eq( p5[ "candidate" ], "Ébonymaws" ) and eq( p5[ "similarity" ], 0.77777777777778 ) and eq( p5[ "levenshtein" ], 3 )
end )

test( "Should not assign any predictions below threshold", function()
    local predictions = {
         [ "Psikutas" ] = { { [ "candidate" ] = "Psipyrtek", [ "similarity" ] = 0.68 } },
         [ "Obszczymucha" ] = { { [ "candidate" ] = "Obszczydupa", [ "similarity" ] = 0.58 } }
    }

    local result = AssignPredictions( predictions, 0.69 )
    
    return eq( CountElements( result ), 0 )
end )

test( "Should assign top predictions equal to or above threshold", function()
    local predictions = {
         [ "Psikutas" ] = { { [ "candidate" ] = "Psipyrtek", [ "similarity" ] = 0.69 } },
         [ "Obszczymucha" ] = { { [ "candidate" ] = "Obszczydupa", [ "similarity" ] = 0.69317 } }
    }

    local result = AssignPredictions( predictions, 0.69 )
    
    return
        eq( result[ "Psikutas" ][ "override" ], "Psipyrtek" ) and eq( result[ "Psikutas" ][ "similarity" ], "69%" ) and
        eq( result[ "Obszczymucha" ][ "override" ], "Obszczydupa" ) and eq( result[ "Obszczymucha" ][ "similarity" ], "69.32%" )
end)

test( "Should format percentages", function()
    return
        eq( formatPercent( 0 ), "0%" ) and
        eq( formatPercent( 0.00012 ), "0.01%" ) and
        eq( formatPercent( 0.0001 ), "0.01%" ) and
        eq( formatPercent( 0.001 ), "0.1%" ) and
        eq( formatPercent( 0.0012 ), "0.12%" ) and
        eq( formatPercent( 0.01 ), "1%" ) and
        eq( formatPercent( 0.012 ), "1.2%" ) and
        eq( formatPercent( 0.1 ), "10%" ) and
        eq( formatPercent( 0.12 ), "12%" ) and
        eq( formatPercent( 0.123 ), "12.3%" ) and
        eq( formatPercent( 0.1234 ), "12.34%" ) and
        eq( formatPercent( 0.12345 ), "12.35%" ) and
        eq( formatPercent( 0.9999 ), "99.99%" ) and
        eq( formatPercent( 1 ), "100%" )
end )

test( "Should order predictions from highest to lowest for Cyakblayt", function()
    local a = { "Cyakblayt" }
    local b = { "Cykablyat", "Aisholay" }
    
    local results = GetSimilarityPredictions( a, b, descending )
    local result = results[ "Cyakblayt" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]

    return
        eq( p1[ "candidate" ], "Aisholay" ) and eq( p1[ "similarity" ], 0.35294117647059 ) and
        eq( p2[ "candidate" ], "Cykablyat" ) and eq( p2[ "similarity" ], 0.24845199749998 )
end )

test( "Should order predictions from highest to lowest for Cyakblayt", function()
    local a = { "Cyakblayt" }
    local b = { "Cykablyat", "Aisholay" }
    
    local results = GetSimilarityPredictions( a, b, improvedDescending )
    local result = results[ "Cyakblayt" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]

    return
        eq( p1[ "candidate" ], "Cykablyat" ) and eq( p1[ "similarity" ], 0.24845199749998 ) and eq( p1[ "levenshtein" ], 0 ) and
        eq( p2[ "candidate" ], "Aisholay" ) and eq( p2[ "similarity" ], 0.35294117647059 ) and eq( p2[ "levenshtein" ], 2 )
end )

test( "Should test Levenshtein implementation", function()
    local f = Levenshtein

    return
        eq( f( "Cykablyat", "Cyakblayt" ), 0 ) and
        eq( f( "Cabcdefgh", "dijklmnop" ), 4 )
end )

test( "Should show similarity between Hørde and Horde", function()
    local a = { "Horde" }
    local b = { "Hørde", "Horde" }
    
    local results = GetSimilarityPredictions( a, b, improvedDescending )
    local result = results[ "Horde" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]

    return
        eq( p1[ "candidate" ], "Horde" ) and eq( p1[ "similarity" ], 1.0 ) and eq( p1[ "levenshtein" ], 0 ) and
        eq( p2[ "candidate" ], "Hørde" ) and eq( p2[ "similarity" ], 0.57495957457607 ) and eq( p2[ "levenshtein" ], 1 )
end )

test( "Should show similarity between Gød and God", function()
    local a = { "God" }
    local b = { "Gød", "God" }
    
    local results = GetSimilarityPredictions( a, b, improvedDescending )
    local result = results[ "God" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]

    return
        eq( p1[ "candidate" ], "God" ) and eq( p1[ "similarity" ], 1.0 ) and eq( p1[ "levenshtein" ], 0 ) and
        eq( p2[ "candidate" ], "Gød" ) and eq( p2[ "similarity" ], 0.28571428571429 ) and eq( p2[ "levenshtein" ], 1 )
end )

test( "Should show similarity between Vtank and Vivo", function()
    local a = { "Vtank" }
    local b = { "Vtank", "Vivo" }
    
    local results = GetSimilarityPredictions( a, b, improvedDescending )
    local result = results[ "Vtank" ]
    local p1 = result[ 1 ]
    local p2 = result[ 2 ]

    return
        eq( p1[ "candidate" ], "Vtank" ) and eq( p1[ "similarity" ], 1.0 ) and eq( p1[ "levenshtein" ], 0 ) and
        eq( p2[ "candidate" ], "Vivo" ) and eq( p2[ "similarity" ], 0.22222222222222 ) and eq( p2[ "levenshtein" ], 1 )
end )
