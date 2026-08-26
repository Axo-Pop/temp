-- Created by Moonlord_A, for hidden_devs and RoDevs scripting application
-- Test game: https://www.roblox.com/games/129784200008761/TEMP
-- Server video showcase: https://youtu.be/3CKn1VM-h08

--- SETUP ---
local LaserCuttingService = {}

--- CONFIGURATIONS ---
local TRIANGLE_STATE_MARGIN = 0.0001 -- Used because sometimes point is on exact point but decimal precision is broken from engine
local GET_VERTEX_KEY_POSITION_PRECISION = 1000 -- Used when getting string of vertex position

--- SERVICES ---
local AssetService = game:GetService("AssetService")

--- HELPER FUNCTIONS ---

-- Used to round vertex position to fix engine decimal point error, converts it to string
local function GetVertexPositionKey(OriginalPosition: Vector3): string
    --[[
        Function is straight forward, 
        string.format takes format and next arguments are applied to it, 
        d is integer.
        Function is used to find and store same vertexes by rounding their position,
        because sometimes there is small decimal error in engine which would make vertex have
        0.000000001 (or smh) mismatch
    ]]
    --
    return string.format(
        "%d_%d_%d",
        math.round(OriginalPosition.X * GET_VERTEX_KEY_POSITION_PRECISION),
        math.round(OriginalPosition.Y * GET_VERTEX_KEY_POSITION_PRECISION),
        math.round(OriginalPosition.Z * GET_VERTEX_KEY_POSITION_PRECISION)
    )
end

-- Used to spawn mesh part from editable mesh
local function CreateMeshPartFromEditableMesh(
    EditableMesh: EditableMesh,
    Part: BasePart,
    ClientReady: boolean
): MeshPart?
    --[[
        Function is made to create mesh part from editable mesh,
        Content.fromObject converts editable mesh to content type and
        later it is used to input in CreateMeshPart function which creates meshpart from it,
        then I just apply same propreties from original part,
        but client would not be able to see it since it lives on server thats why first we
        use CreateDataModelContentAsync to bake data in memory and create temporarly data model
         so client can see it
    ]]
    --

    -- Set mesh contentn to editable mesh
    local MeshContent = Content.fromObject(EditableMesh)

    -- If we want client to see mesh aswell
    if ClientReady then
        -- Attempt to make new content
        local succes, result, contentId = pcall(function()
            return AssetService:CreateDataModelContentAsync(MeshContent)
        end)

        -- Check if we succeed
        if not succes or result ~= Enum.CreateContentResult.Success then
            warn("LaserCuttingSerivce | Failed to make client ready content -", Part, " - ", result)
            EditableMesh:Destroy()
            return
        end

        -- Set content to this
        MeshContent = contentId
    end

    -- Try to make mesh part from editable mesh
    local succes, MeshPart = pcall(function()
        return AssetService:CreateMeshPartAsync(MeshContent)
    end)

    -- if not succes warn
    if not succes then
        warn("LaserCuttingSerivce | Failed to convert part to mesh -", Part, " - ", MeshPart)
        EditableMesh:Destroy()
        return
    end

    -- Inherit important propreties
    MeshPart.Name = Part.Name
    MeshPart.CFrame = Part.CFrame
    MeshPart.Anchored = Part.Anchored
    MeshPart.CanCollide = Part.CanCollide
    MeshPart.Color = Part.Color
    MeshPart.CastShadow = Part.CastShadow
    MeshPart.Material = Part.Material
    MeshPart.Transparency = Part.Transparency
    MeshPart.AssemblyLinearVelocity = Part.AssemblyLinearVelocity

    return MeshPart
end

-- Used to make square side on editable mesh
local function CreateSquareSide(
    EditableMesh: EditableMesh,
    Width: number,
    Height: number,
    UpVector: Vector3,
    RightVector: Vector3,
    FacePosition: Vector3
)
    --[[
        Function just created 2 triangles 1 by 1, 
        it is getting vertex position with just basic math for example
        Firstvertex is getting it by adding faceposition which is like origin to
        upvector which is direction of height and it multiplys by half height since faceposition
        is in middle, same procces for right vector,
        later it just uses addtriangle function and puts vertexes id to it
    ]]
    --

    -- First triangle
    local FirstVertexId = EditableMesh:AddVertex(FacePosition + (UpVector * Height / 2) - (RightVector * Width / 2)) -- Top left
    local SecondVertexId = EditableMesh:AddVertex(FacePosition - (UpVector * Height / 2) - (RightVector * Width / 2)) -- Bottom left
    local ThirtdVertexId = EditableMesh:AddVertex(FacePosition - (UpVector * Height / 2) + (RightVector * Width / 2)) -- Bottom right

    -- Create first triange
    EditableMesh:AddTriangle(FirstVertexId, SecondVertexId, ThirtdVertexId)

    -- Second triangle we only need 1 new vertex
    local ForthVertexId = EditableMesh:AddVertex(FacePosition + (UpVector * Height / 2) + (RightVector * Width / 2)) -- Top right

    -- Create Second triange
    EditableMesh:AddTriangle(ThirtdVertexId, ForthVertexId, FirstVertexId)
end

-- Used to transform part to mesh part , taking important propreties and children, returns mesh part
local function TransformPartToMeshPart(Part: BasePart): any
    --[[
        Function is used to manualy make editable mesh from part,
        roblox parts have 24 vertices which makes sides look sharp,
        I  run function CreateSquareSide and input axis relative to that side,
        for example for front side upvector and right vector are its height direction,
        and zaxis is its look vector which i just multiply by half of Z, because position is in middle
        and width direction, vertices in editable mesh use local space from editable mesh
    ]]
    --
    -- Create editable mesh and mesh part
    local EditableMesh = AssetService:CreateEditableMesh()

    -- Prepare half size
    local HalfSize = Part.Size / 2

    -- Get important directions
    local YAxis = Vector3.yAxis
    local ZAxis = Vector3.zAxis
    local XAxis = Vector3.xAxis

    -- Add each side to editable mesh
    CreateSquareSide(EditableMesh, Part.Size.X, Part.Size.Y, YAxis, XAxis, ZAxis * HalfSize.Z) -- Front face
    CreateSquareSide(EditableMesh, Part.Size.X, Part.Size.Y, YAxis, -XAxis, -ZAxis * HalfSize.Z) -- Back face
    CreateSquareSide(EditableMesh, Part.Size.X, Part.Size.Z, -ZAxis, XAxis, YAxis * HalfSize.Y) -- Top face
    CreateSquareSide(EditableMesh, Part.Size.X, Part.Size.Z, ZAxis, XAxis, -YAxis * HalfSize.Y) -- Bottom face
    CreateSquareSide(EditableMesh, Part.Size.Z, Part.Size.Y, YAxis, -ZAxis, XAxis * HalfSize.X) -- Right face
    CreateSquareSide(EditableMesh, Part.Size.Z, Part.Size.Y, YAxis, ZAxis, -XAxis * HalfSize.X) -- Left face

    -- Create mesh part form editable mesh
    local MeshPart = CreateMeshPartFromEditableMesh(EditableMesh, Part)
    if not MeshPart then
        return
    end

    -- Spawn mesh part
    MeshPart.Parent = Part.Parent

    -- Destroy old part
    Part:Destroy()

    return MeshPart, EditableMesh
end

-- Used to get vertex sign
local function GetVertexSign(VertexPosition: Vector3, PlanePosition: Vector3, PlaneUpVector: Vector3): number
    --[[
        Function used to indentify if vertex is above, on or below plane,
        we take direction form plane to vertex and then calculate dot product
        from it and planeupvector, dot product returns cos of angel between
        two directions multiplyed by their length.
        Based on result it will tell us whenever its on plane, above or below
        we use TRIANGLE_STATE_MARGIN because there are engine precision errors ( already talked about them)
    ]]
    --
    -- Calculate direction to plane origin
    local VertexDirectionToOrigin = VertexPosition - PlanePosition

    -- Calculate dot product to decide sign
    local DotProduct = VertexDirectionToOrigin:Dot(PlaneUpVector)

    -- If bigger than TRIANGLE_STATE_MARGIN then is above
    if DotProduct > TRIANGLE_STATE_MARGIN then
        return 1
    elseif DotProduct < -TRIANGLE_STATE_MARGIN then -- If less than is below
        return -1
    else
        return 0
    end
end

-- Used to get intersecting triangle data
local function GetIntersectingTriangleVertexData(
    TriangleData: { any },
    PlanePosition: Vector3,
    PlaneUpVector: Vector3
): { any }
    --[[
        Function is used to make calculating cleaner, 
        by storing vertex positions and signs,
        which makes later calculation in interceting triangles cleaner
    ]]
    --

    -- Create table
    local VertexData = {}

    -- Loop to get all vertex data
    for i = 1, 3 do -- There are only 3 vertexes
        -- Add first vertex
        VertexData[i] = {
            Position = TriangleData[i],
            Sign = GetVertexSign(TriangleData[i], PlanePosition, PlaneUpVector),
        }
    end

    -- Return result
    return VertexData
end

-- Used to find position for new vertex from inside and outside position
local function GetNewVertexPosition(
    InsidePosition: Vector3,
    OutsidePosition: Vector3,
    PlaneUpVector: Vector3,
    PlanePosition: Vector3
): Vector3
    --[[
        Function is used when we have triangle side that is intersecting plane,
        we first calculate line direction and then dot product with plane up vector.
        we can calculate distance start point of that line has to move to be on plane by
        dividing dot product of direction from start point to plane by dot product we from line direction
        and plane up vector.
    ]]
    --
    -- Prepare start variables
    local LineDirection = OutsidePosition - InsidePosition
    local DotProduct = LineDirection:Dot(PlaneUpVector)

    -- If 2 directions are paraller
    if math.abs(DotProduct) < TRIANGLE_STATE_MARGIN then
        return InsidePosition:Lerp(OutsidePosition, 0.5)
    end

    -- Calculate distance to plane touch point
    local DistanceToPlane = (PlanePosition - InsidePosition):Dot(PlaneUpVector) / DotProduct

    -- Calculate new position and return
    return InsidePosition + (LineDirection * DistanceToPlane)
end

-- Used to calculate mesh normals for lightning
local function CalculateMeshNormals(EditableMesh: EditableMesh)
    --[[
        Function is used to calculate normals of faces after creating mesh,
        we get normal direction by using cross product which for exmaple if we plug in 
        lookvector and right vector will give us up vector, we will get vector 90 degress to 
        vectors we input.
        When we calculate normals we just add them to mesh and set normal id to all vertecies
    ]]
    --

    -- Iterate thorugh faces
    for _, FaceId in EditableMesh:GetFaces() do
        -- Get vertexes
        local Vertexes = EditableMesh:GetFaceVertices(FaceId)

        -- If face is valid triangle
        if #Vertexes == 3 then
            -- Get vertex positions
            local VertexPosition1 = EditableMesh:GetPosition(Vertexes[1])
            local VertexPosition2 = EditableMesh:GetPosition(Vertexes[2])
            local VertexPosition3 = EditableMesh:GetPosition(Vertexes[3])

            -- Calculate normal direction using Cross Product
            local NormalDirection = (VertexPosition2 - VertexPosition1):Cross(VertexPosition3 - VertexPosition1)

            -- Validate if vector is valid
            if NormalDirection.Magnitude > 0 then
                NormalDirection = NormalDirection.Unit
            else
                NormalDirection = Vector3.yAxis
            end

            -- Add normal to mesh
            local NormalId = EditableMesh:AddNormal(NormalDirection)

            -- Update face vertexes
            EditableMesh:SetFaceNormals(FaceId, { NormalId, NormalId, NormalId })
        end
    end
end

--- FUNCTIONS ---

-- Used to get all vertexes state from part and with plane
function LaserCuttingService.GetTrianglesState(Mesh: EditableMesh, PlaneUpVector: Vector3, PlanePosition: Vector3)
    --[[
        This function will take all triangles from editable mesh and calculate whenever
        they are above, below or instersecting with cut plane.
        (Vertex sign calculation is described in its function)
        Since triangle has 3 vertexes if one of them is intersecting then triangle 
        is intersecting with plane, or if 2 vertexes have diffrent signs 
        ( 1 is below plane and other is above), means that side of triangle is intersecting
        We store them all in table and return result
    ]]
    --

    -- Prepare storage for vertexes states
    local AboveTriangles = {}
    local IntersectingTriangles = {}
    local BelowTriangles = {}

    -- Get all editable mesh faces
    local MeshFaces = Mesh:GetFaces()

    -- Iterate through them and assign state from up vector
    for _, FaceId in MeshFaces do
        -- Prepare temp variables for helping to decide state
        local AmountOfVertexesAbove = 0
        local AmountOfVertexesIntersecting = 0
        local AmountOfVertexesBelow = 0

        -- First we get all vertexes from face
        local Vertexes = Mesh:GetFaceVertices(FaceId)

        -- Create triangle data
        local TriangleData = {} -- Store vertex positions

        -- Iterate through them and check state
        for _, VertexId in Vertexes do
            -- Get vertex position
            local VertexPosition = Mesh:GetPosition(VertexId)

            -- Get vertex sign
            local VertexSign = GetVertexSign(VertexPosition, PlanePosition, PlaneUpVector)

            -- Increment value based on sign
            if VertexSign == 1 then
                AmountOfVertexesAbove += 1
            elseif VertexSign == -1 then
                AmountOfVertexesBelow += 1
            else
                AmountOfVertexesIntersecting += 1
            end

            -- Add to triangle data
            table.insert(TriangleData, VertexPosition)
        end

        -- Decide triangle state
        if AmountOfVertexesIntersecting > 0 or AmountOfVertexesAbove > 0 and AmountOfVertexesBelow > 0 then
            table.insert(IntersectingTriangles, TriangleData)
        elseif AmountOfVertexesAbove > 0 then
            table.insert(AboveTriangles, TriangleData)
        else
            table.insert(BelowTriangles, TriangleData)
        end
    end

    -- Retrun results
    return AboveTriangles, IntersectingTriangles, BelowTriangles
end

-- Used to get editable mesh part and transform part to editable mesh part, returns editable mesh instance
function LaserCuttingService.GetOrTransfromToEditableMesh(Part: BasePart): EditableMesh?
    --[[
        This function is just used to return editable mesh from part,
        by creating it from part or extracting mesh content from mesh part.
        MeshContent is used first because if it was generated in current session 
        (if part was already cut) then id would give error, and id can be used if
        meshcontent is unavailable and mesh is actual mesh uploaded to roblox
    ]]
    --

    -- Store varaible
    local EditableMesh = nil

    -- Check if part is not mesh part, if no then transform it to one
    if not Part:IsA("MeshPart") then
        -- Transform part to mesh part and type cast to mesh part for editor
        Part, EditableMesh = TransformPartToMeshPart(Part)

        -- Check if we have successfully created part, if not return
        if not Part or not EditableMesh then
            return nil
        end

        return EditableMesh, Part -- Early return
    end

    -- Get mesh content
    local MeshContent = Part.MeshContent

    if not MeshContent then
        MeshContent = Content.fromUri(Part.MeshId)
    end

    -- Create editable mesh instance
    local success, EditableMesh = pcall(function()
        return AssetService:CreateEditableMeshAsync(MeshContent)
    end)

    -- If it failed to create we return false and warn
    if not success or not EditableMesh then
        warn("LaserCuttingService | Could not create editable mesh - ", EditableMesh)
        return nil
    end

    return EditableMesh, Part
end

-- Used to fill cutted side with triangles
function LaserCuttingService.FillWithTriangles(
    EditableMesh: EditableMesh,
    EdgeVertexPair: { any },
    PlaneUpVector: Vector3,
    VertexSign: number
)
    --[[
        Function is used to fill cutted side of part with triangles as it 
        dosent have them there, edgevertex pair is pair of vertexes that are from 
        some triangle that is one of last ones, we could take 1 vertex and treat it as middle vertex
        or generate new one that is in middle and then fill triangles with  it as top point,
        we calculate midpoint with adding all positions and dividing them with amount of them,
        later we just take pairs of vertexes and new midpoint to create triangles,
        we also have to make sure triangle is facing outside side if triangles are facing
        inside then it will be not rendered (from outside look), logic for calculation is similar
        with one in calculatefacenormals and we check angel it has with direction it should have,
        by swaping first 2 vertexes is how we flip triangle to face other side
    ]]
    --

    -- Prepare variables for middle calculation
    local TotalPositions = Vector3.zero
    local PositionsCount = 0

    -- Position to vertex table
    local PositionToVertex = {}

    -- Iterate through all vertexes
    for _, PairData in EdgeVertexPair do
        for _, VertexPosition in PairData do
            -- Get vertex position key
            local PositionKey = GetVertexPositionKey(VertexPosition)

            -- Check if vertex does not exists
            if not PositionToVertex[PositionKey] then
                -- Add to total positions
                TotalPositions += VertexPosition

                -- Add vertex to mesh
                local VertexId = EditableMesh:AddVertex(VertexPosition)

                -- Update variables
                PositionToVertex[PositionKey] = VertexId
                PositionsCount += 1
            end
        end
    end

    -- Calculate midpoint
    local CurrentMidPoint = TotalPositions / PositionsCount

    -- Create midpoint vertex
    local MidpointVertexId = EditableMesh:AddVertex(CurrentMidPoint)

    -- Calcaulte normal
    local FaceNormal = PlaneUpVector * -VertexSign

    -- Fill with triangles
    for _, PairData in EdgeVertexPair do
        -- Get vertexes
        local VertexPosition1 = PairData[1]
        local VertexPosition2 = PairData[2]

        -- Calculate where current triangle is facing
        local TriangleNormal = (VertexPosition2 - VertexPosition1):Cross(CurrentMidPoint - VertexPosition1)

        -- Check if they are facing opposite directions
        if TriangleNormal:Dot(FaceNormal) < 0 then
            -- Swap positions
            VertexPosition1, VertexPosition2 = VertexPosition2, VertexPosition1
        end

        -- Get vertex ids
        local VertexId1 = GetVertexPositionKey(VertexPosition1)
        local VertexId2 = GetVertexPositionKey(VertexPosition2)

        -- Create triangles
        EditableMesh:AddTriangle(PositionToVertex[VertexId1], PositionToVertex[VertexId2], MidpointVertexId)
    end
end

-- Used to fulfill editable mesh data and generate new vertexes from cut
function LaserCuttingService.CreateAndCutMesh(
    EditableMesh: EditableMesh,
    OwnedTriangles: { any },
    IntersectingTriangles: { any },
    PlaneUpVector: Vector3,
    PlanePosition: Vector3,
    VertexSign: number -- Used to tell which vertexes on intersecting triangles belong to mesh
)
    --[[
        This functon is most important one, as it is one that does cutting overall,
        we first make all triangles that we know mesh fully owns,
        in intersecting triangles we take look at its sides by taking
        current vertex and next one in triangledata,
        we check if current vertex has correct sign and add it straight to triangle data 
        as we will have that vertex, and also we check if it is intersecting then we add it
        straight to intersecting positions, there should only be 2 intersecting positions in 
        valid triangle, if current and next vertex signs are not same (but not 0) it means
        that triangle side is intersecting with plane and then we calculate new vertex that replaces
        one vertex that is on wrong side, (calculation logic is covered in that function),
        sometimes we will only generate 1 triangle and sometimes 2, it depends if 1 or 2 vertexes 
        are on wrong side, if its 1 then we will generate 2 as we will generate 2 new positions + 2 we have,
        we just fill triangles in clockwise order and they will face correct direction,
        we also add interceting positions if there are 2 to edgevertexpair which is used to fill triangles
    ]]
    --

    -- Prepare variables
    local EdgeVertexPair = {} -- Used to fill face at the end

    -- Loop through exsisting triangles and add to mesh
    for _, TriangleData in OwnedTriangles do
        -- Store vertexId to make triangle
        local VertexIds = {}

        for _, VertexPosition in TriangleData do
            -- Get vertex id
            local VertexId = EditableMesh:AddVertex(VertexPosition)

            -- Store id for triangle
            table.insert(VertexIds, VertexId)
        end

        -- Create triangle from vertexids
        EditableMesh:AddTriangle(VertexIds[1], VertexIds[2], VertexIds[3])
    end

    -- Loop through intersecting triangles to find new vertex positions
    for _, TriangleData in IntersectingTriangles do
        -- Get triangle vertex data
        local VertexesData = GetIntersectingTriangleVertexData(TriangleData, PlanePosition, PlaneUpVector)

        -- Prepare variable for data gathering
        local TrianglePositions = {}
        local IntersectingPositions = {}

        -- Loop thorugh all vertexes and assign them
        for i = 1, 3 do
            -- Get current and next vertex data
            local VertexData = VertexesData[i]
            local NextVertexData = VertexesData[i % 3 + 1]

            -- If belongs to this mesh then add him
            if VertexData.Sign == VertexSign or VertexData.Sign == 0 then
                table.insert(TrianglePositions, VertexData.Position)
            end

            -- If is intersecting vertex store him
            if VertexData.Sign == 0 then
                table.insert(IntersectingPositions, VertexData.Position)
            end

            -- Check if this side (line) is intersecting plane
            if
                (VertexData.Sign == 1 and NextVertexData.Sign == -1)
                or (VertexData.Sign == -1 and NextVertexData.Sign == 1)
            then
                -- Calculate new position for vertex
                local NewPos =
                    GetNewVertexPosition(VertexData.Position, NextVertexData.Position, PlaneUpVector, PlanePosition)

                -- Store position to tables
                table.insert(TrianglePositions, NewPos)
                table.insert(IntersectingPositions, NewPos)
            end
        end

        -- Generate triangles
        if #TrianglePositions >= 3 then
            -- Get first vertex
            local FirstVertex = EditableMesh:AddVertex(TrianglePositions[1])
            for i = 2, #TrianglePositions - 1 do
                -- Add vertexes to the mesh
                local SecondVertex = EditableMesh:AddVertex(TrianglePositions[i])
                local ThirdVertex = EditableMesh:AddVertex(TrianglePositions[i + 1])

                -- Create triangle from generated vertexes
                EditableMesh:AddTriangle(FirstVertex, SecondVertex, ThirdVertex)
            end
        end

        -- If there is 2 intersecting points generted from this triangle then store them for later filling
        if #IntersectingPositions == 2 then
            table.insert(EdgeVertexPair, IntersectingPositions)
        end
    end

    -- Call fill function to fill empty faces
    LaserCuttingService.FillWithTriangles(EditableMesh, EdgeVertexPair, PlaneUpVector, VertexSign)
end

-- Used to request part cutting
function LaserCuttingService.RequestPartCutting(
    Part: BasePart, -- Part which will be cutted
    PlaneCFrame: CFrame
)
    --[[
        This function is start function that takes input and slowly takes them to all functions,
        we have first transfer plane position and up vector to local space from part because
        editable mesh vertices have position from that local space.
        Then we just call function by function and at then and spawn meshes.
    ]]
    --

    -- Convert true plane position to local place position relative to part
    local LocalPlanePosition = Part.CFrame:PointToObjectSpace(PlaneCFrame.Position)
    local LocalPlaneUpVector = Part.CFrame:VectorToObjectSpace(PlaneCFrame.UpVector)

    -- Transfrom and get editable mesh, type cast for editor --
    local EdtiableMesh, Part = LaserCuttingService.GetOrTransfromToEditableMesh(Part)

    -- Check if aquiring editable mesh was successfull
    if not EdtiableMesh then
        return
    end

    -- Get all vertexes and their state (above, intersecting, below), we get them from faces on editable mesh
    local AboveTriangles, IntersectingTriangles, BelowTriangles =
        LaserCuttingService.GetTrianglesState(EdtiableMesh, LocalPlaneUpVector, LocalPlanePosition)

    -- Check if intersecting triangles is empty, then we dont have to proceed
    if #IntersectingTriangles <= 0 then
        return
    end

    -- Prepare new meshes
    local UpperMesh = AssetService:CreateEditableMesh()
    local LowerMesh = AssetService:CreateEditableMesh()

    -- Create data in mesh and cut , up part
    LaserCuttingService.CreateAndCutMesh(
        UpperMesh,
        AboveTriangles,
        IntersectingTriangles,
        LocalPlaneUpVector,
        LocalPlanePosition,
        1
    )

    -- Create data in mesh and cut , bottom part
    LaserCuttingService.CreateAndCutMesh(
        LowerMesh,
        BelowTriangles,
        IntersectingTriangles,
        LocalPlaneUpVector,
        LocalPlanePosition,
        -1
    )

    -- Gemerate normals
    CalculateMeshNormals(UpperMesh)
    CalculateMeshNormals(LowerMesh)

    -- Create new mesh parts
    local UpperMeshPart = CreateMeshPartFromEditableMesh(UpperMesh, Part, true)
    local LowerMeshPart = CreateMeshPartFromEditableMesh(LowerMesh, Part, true)

    -- Check if creation of both was successfull
    if not UpperMeshPart or not LowerMeshPart then
        if UpperMeshPart then -- Destroy which we have
            UpperMeshPart:Destroy()
        end
        if LowerMeshPart then
            LowerMeshPart:Destroy()
        end

        -- Destory editable meshes
        UpperMesh:Destroy()
        LowerMesh:Destroy()
        return
    end

    -- Spawn new meshes
    UpperMeshPart.Parent = Part.Parent
    LowerMeshPart.Parent = Part.Parent

    -- Destory old part
    Part:Destroy()
end

return LaserCuttingService
