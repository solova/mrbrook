sceneRenderTarget = undefined

SCREEN_WIDTH = window.innerWidth
SCREEN_HEIGHT = window.innerHeight
STARTX = -3000
renderer = undefined
container = undefined
stats = undefined
camera = undefined
scene = undefined
cameraOrtho = undefined
sceneRenderTarget = undefined
uniformsNoise = undefined
uniformsNormal = undefined
heightMap = undefined
normalMap = undefined
quadTarget = undefined
directionalLight = undefined
pointLight = undefined
terrain = undefined
textureCounter = 0
animDelta = 0
animDeltaDir = -1
lightVal = 0
lightDir = 1
soundVal = 0
oldSoundVal = 0
soundDir = 1
clock = new THREE.Clock()
morph = undefined
morphs = []
statics = []
updateNoise = true
animateTerrain = false
textMesh1 = undefined
mlib = {}
cursorPosition = 0
riverPosition = 0

record = 0
oldSpeed = 0
speed = 1
speedTimeout = 0
controls = undefined
uniformsTerrain = undefined
composer = undefined
stopTimeout = 0

waterMesh = undefined

scores = 0
scoresTimeout = 0

started = no

soundtrack = undefined

riverBlock = document.getElementById('river')

updateRiverPosition = (pos) ->
	riverPosition = pos
	riverBlock.style.left = -150 + SCREEN_WIDTH * (riverPosition+1)/2 + "px"

setRiverPosition = (delta) ->

	if Math.abs(cursorPosition-riverPosition) < 0.01
		return
	
	if riverPosition > cursorPosition
		updateRiverPosition (riverPosition - 0.5 * delta)
	else
		updateRiverPosition (riverPosition + 0.5 * delta)

checkhit = (position) ->
	nposition = position/1000
	if Math.abs(nposition-riverPosition) < 0.4
		gameover()

increaseSpeed = ->
	speed = Math.max(1, Math.min(speed*1.25, 10))
	if speed<10
		speedTimeout = setTimeout increaseSpeed, Math.ceil(speed*1000)
increaseScores = ->
	scores += Math.floor(speed)
	document.getElementById('scores').innerHTML = scores.toString()
	scoresTimeout = setTimeout increaseScores, 100

play = ->
	scores = 0
	oldSpeed = 0
	clearTimeout stopTimeout
	clearTimeout speedTimeout
	increaseSpeed()
	clearTimeout scoresTimeout
	increaseScores()
	soundtrack.position = 0
	soundtrack.play()

	lightDir = 1
	started = yes

	document.getElementById('start').style.display = 'none'
	document.getElementById('help').style.display = "flex"
	setTimeout (-> document.getElementById('help').style.opacity = "0.0"), 0
	document.getElementById('info').style.display = 'block'
	document.getElementById('river').style.display = 'block'
	document.getElementById('river').style.opacity = 0.75

gameover = ->
	clearTimeout speedTimeout
	clearTimeout scoresTimeout
	oldSpeed = 0
	speed = 1
	record = Math.max scores, record
	scores = 0

	lightDir = -1
	
	document.getElementById('river').style.opacity = 0.0
	document.getElementById('record').innerHTML = record

	document.getElementById('start').style.display = 'flex'
	document.getElementById('start').innerHTML = "Game Over" 
	stopTimeout = setTimeout (->  soundtrack.pause(); document.getElementById('start').innerHTML = "Touch to Start" ), 2500

	document.getElementById('help').style.display = "none"
	document.getElementById('help').style.opacity = "1.0"
	document.getElementById('info').style.display = 'none'

onTouchStart = (event) ->
	if event.touches.length==1
		cursorPosition = 2*event.changedTouches[0].pageX/SCREEN_WIDTH - 1.0

onTouchMove = (event) ->
	if event.touches.length==1
		cursorPosition = 2*event.changedTouches[0].pageX/SCREEN_WIDTH - 1.0
		# console.log 'touch move', riverPosition
	

onTouchEnd = (event) ->

onWindowResize = (event) ->
	SCREEN_WIDTH = window.innerWidth
	SCREEN_HEIGHT = window.innerHeight
	renderer.setSize SCREEN_WIDTH, SCREEN_HEIGHT
	camera.aspect = SCREEN_WIDTH / SCREEN_HEIGHT
	camera.updateProjectionMatrix()

# onKeyDown = ( event ) ->
# 	switch event.keyCode
# 		when 78 then lightDir *= -1
# 		when 77 then animDeltaDir *= -1
# 		when 66 then soundDir *= -1

loadTextures = ->
	textureCounter += 1
	if textureCounter is 3
		terrain.visible = true
		document.getElementById("loading").style.display = "none"
		document.getElementById("start").style.display = "flex"

applyShader = (shader, texture, target) ->
	shaderMaterial = new THREE.ShaderMaterial(
		fragmentShader: shader.fragmentShader
		vertexShader: shader.vertexShader
		uniforms: THREE.UniformsUtils.clone(shader.uniforms)
	)
	shaderMaterial.uniforms["tDiffuse"].value = texture
	sceneTmp = new THREE.Scene()
	meshTmp = new THREE.Mesh(new THREE.PlaneGeometry(SCREEN_WIDTH, SCREEN_HEIGHT), shaderMaterial)
	meshTmp.position.z = -500
	sceneTmp.add meshTmp
	renderer.render sceneTmp, cameraOrtho, target, true

init = ->
	container = document.getElementById 'container'
	soundtrack = document.getElementById 'soundtrack'
	soundtrack.pause()

	sceneRenderTarget = new THREE.Scene()

	cameraOrtho = new THREE.OrthographicCamera SCREEN_WIDTH / -2, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, SCREEN_HEIGHT / -2, -20000, 20000
	cameraOrtho.position.z = 500

	sceneRenderTarget.add cameraOrtho

	camera = new THREE.PerspectiveCamera 80, SCREEN_WIDTH / SCREEN_HEIGHT, 2, 4000
	camera.position.set -1024, 512, 0

	controls = new THREE.TrackballControls( camera );
	controls.target.set 0, 0, 0

	controls.rotateSpeed = 1.0

	controls.noZoom = yes 
	controls.noPan = yes
	controls.noRoll = yes  

	controls.staticMoving = yes 
	controls.dynamicDampingFactor = 0.15 

	scene = new THREE.Scene()
	scene.fog = new THREE.Fog 0x050505, 2000, 4000

	directionalLight = new THREE.DirectionalLight 0xffffff, 1.15
	directionalLight.position.set 500, 2000, 0 

	pointLight = new THREE.PointLight 0xff4400, 1.5 
	pointLight.position.set 0, 0, 0

	scene.add directionalLight
	scene.add pointLight

	normalShader = THREE.NormalMapShader
	rx = 256
	ry = 256
	pars =
		minFilter: THREE.LinearMipmapLinearFilter
		magFilter: THREE.LinearFilter
		format: THREE.RGBFormat

	heightMap = new THREE.WebGLRenderTarget(rx, ry, pars)
	normalMap = new THREE.WebGLRenderTarget(rx, ry, pars)
	uniformsNoise =
		time:
			type: "f"
			value: 1.0
		scale:
			type: "v2"
			value: new THREE.Vector2(1.5, 1.5)
		offset:
			type: "v2"
			value: new THREE.Vector2(0, 0)

	uniformsNormal = THREE.UniformsUtils.clone(normalShader.uniforms)
	uniformsNormal.height.value = 0.05
	uniformsNormal.resolution.value.set rx, ry
	uniformsNormal.heightMap.value = heightMap
	vertexShader = document.getElementById("vertexShader").textContent

	# TEXTURES
	specularMap = new THREE.WebGLRenderTarget(2048, 2048, pars)
	diffuseTexture1 = THREE.ImageUtils.loadTexture("images/textures/grasslight-big.jpg", null, ->
	  loadTextures()
	  applyShader THREE.LuminosityShader, diffuseTexture1, specularMap
	)
	diffuseTexture2 = THREE.ImageUtils.loadTexture("images/textures/backgrounddetailed6.jpg", null, loadTextures)
	detailTexture = THREE.ImageUtils.loadTexture("images/textures/grasslight-big-nm.jpg", null, loadTextures)
	diffuseTexture1.wrapS = diffuseTexture1.wrapT = THREE.RepeatWrapping
	diffuseTexture2.wrapS = diffuseTexture2.wrapT = THREE.RepeatWrapping
	detailTexture.wrapS = detailTexture.wrapT = THREE.RepeatWrapping
	specularMap.wrapS = specularMap.wrapT = THREE.RepeatWrapping

	# TERRAIN SHADER
	terrainShader = THREE.ShaderTerrain["terrain"]
	uniformsTerrain = THREE.UniformsUtils.clone(terrainShader.uniforms)
	uniformsTerrain["tNormal"].value = normalMap
	uniformsTerrain["uNormalScale"].value = 3.5
	uniformsTerrain["tDisplacement"].value = heightMap
	uniformsTerrain["tDiffuse1"].value = diffuseTexture1
	uniformsTerrain["tDiffuse2"].value = diffuseTexture2
	uniformsTerrain["tSpecular"].value = specularMap
	uniformsTerrain["tDetail"].value = detailTexture
	uniformsTerrain["enableDiffuse1"].value = true
	uniformsTerrain["enableDiffuse2"].value = true
	uniformsTerrain["enableSpecular"].value = true
	uniformsTerrain["uDiffuseColor"].value.setHex 0xffffff
	uniformsTerrain["uSpecularColor"].value.setHex 0xffffff
	uniformsTerrain["uAmbientColor"].value.setHex 0x111111
	uniformsTerrain["uShininess"].value = 30
	uniformsTerrain["uDisplacementScale"].value = 175
	uniformsTerrain["uRepeatOverlay"].value.set 6, 6
	params = [["heightmap", document.getElementById("fragmentShaderNoise").textContent, vertexShader, uniformsNoise, false], ["normal", normalShader.fragmentShader, normalShader.vertexShader, uniformsNormal, false], ["terrain", terrainShader.fragmentShader, terrainShader.vertexShader, uniformsTerrain, true]]
	i = 0

	while i < params.length
		material = new THREE.ShaderMaterial(
			uniforms: params[i][3]
			vertexShader: params[i][2]
			fragmentShader: params[i][1]
			lights: params[i][4]
			fog: true
		)
		mlib[params[i][0]] = material
		i++
	plane = new THREE.PlaneGeometry(SCREEN_WIDTH, SCREEN_HEIGHT)
	quadTarget = new THREE.Mesh(plane, new THREE.MeshBasicMaterial(color: 0x000000))
	quadTarget.position.z = -500
	sceneRenderTarget.add quadTarget

	# TERRAIN MESH
	geometryTerrain = new THREE.PlaneGeometry(6000, 6000, 256, 256)
	geometryTerrain.computeFaceNormals()
	geometryTerrain.computeVertexNormals()
	geometryTerrain.computeTangents()
	terrain = new THREE.Mesh(geometryTerrain, mlib["terrain"])
	terrain.position.set 0, -125, 0
	terrain.rotation.x = -Math.PI / 2
	terrain.visible = false
	scene.add terrain

	renderer = new THREE.WebGLRenderer();
	renderer.setSize(SCREEN_WIDTH, SCREEN_HEIGHT);
	renderer.setClearColor(scene.fog.color, 1);

	renderer.domElement.style.position = "absolute"
	renderer.domElement.style.top = "0px"
	renderer.domElement.style.left = "0px"

	container.appendChild renderer.domElement

	renderer.gammaInput = true
	renderer.gammaOutput = true

	onWindowResize()
	window.addEventListener( 'resize', onWindowResize, false )
	# document.addEventListener( 'keydown', onKeyDown, false )
	document.addEventListener( 'touchstart', onTouchStart, false )
	document.addEventListener( 'touchmove', onTouchMove, false )
	document.addEventListener( 'touchend', onTouchEnd, false )



	renderer.autoClear = false

	renderTargetParameters =
		minFilter: THREE.LinearFilter,
		magFilter: THREE.LinearFilter,
		format: THREE.RGBFormat,
		stencilBufer: false
	renderTarget = new THREE.WebGLRenderTarget(SCREEN_WIDTH, SCREEN_HEIGHT, renderTargetParameters);

	effectBloom = new THREE.BloomPass(0.6)
	effectBleach = new THREE.ShaderPass(THREE.BleachBypassShader)
	hblur = new THREE.ShaderPass(THREE.HorizontalTiltShiftShader)
	vblur = new THREE.ShaderPass(THREE.VerticalTiltShiftShader)
	bluriness = 2
	hblur.uniforms["h"].value = bluriness / SCREEN_WIDTH
	vblur.uniforms["v"].value = bluriness / SCREEN_HEIGHT
	hblur.uniforms["r"].value = vblur.uniforms["r"].value = 0.5
	effectBleach.uniforms["opacity"].value = 0.65
	renderModel = new THREE.RenderPass(scene, camera)
	vblur.renderToScreen = true
	composer = new THREE.EffectComposer(renderer, renderTarget)
	composer.addPass renderModel
	composer.addPass effectBloom

	# composer.addPass effectBleach
	composer.addPass hblur
	composer.addPass vblur

	addMorph = (geometry, speed, duration, x, y, z) ->
		material = new THREE.MeshLambertMaterial
			color: 0xffaa55
			morphTargets: true
			vertexColors: THREE.FaceColors
		
		meshAnim = new THREE.MorphAnimMesh(geometry, material)
		meshAnim.speed = speed
		meshAnim.duration = duration
		meshAnim.time = 600 * Math.random()
		meshAnim.position.set x, y, z
		meshAnim.rotation.y = Math.PI / 2
		meshAnim.castShadow = true
		meshAnim.receiveShadow = false
		scene.add meshAnim
		morphs.push meshAnim
		renderer.initWebGLObjects scene

	addStatic = (geometry, materials, x, y, z) ->

		meshAnim = new THREE.Mesh( geometry, new THREE.MeshFaceMaterial( materials ) );
		meshAnim.speed = 250
		meshAnim.duration = 500
		meshAnim.time = 600 * Math.random()
		meshAnim.scale.set 4,4,4
		meshAnim.position.set x, y, z
		meshAnim.rotation.y = Math.PI / 2 - z/1500.0
		meshAnim.castShadow = true
		meshAnim.receiveShadow = false
		meshAnim.start = x
		meshAnim.checked = no
		scene.add meshAnim
		statics.push meshAnim
		renderer.initWebGLObjects scene

	morphColorsToFaceColors = (geometry) ->
		if geometry.morphColors and geometry.morphColors.length
			colorMap = geometry.morphColors[0]
			i = 0

		while i < colorMap.colors.length
			geometry.faces[i].color = colorMap.colors[i]
			i++

	loader = new THREE.JSONLoader()
	loader.load "js/models/parrot.js", (geometry) ->
		morphColorsToFaceColors geometry
		addMorph(geometry, 250, 500, STARTX - 500, 500, 700)
		addMorph(geometry, 250, 500, STARTX - Math.random() * 500, 500, -200)
		addMorph(geometry, 250, 500, STARTX - Math.random() * 500, 500, 200)
		addMorph(geometry, 250, 500, STARTX - Math.random() * 500, 500, 1000)

	loader.load "js/models/flamingo.js", (geometry) ->
		morphColorsToFaceColors geometry
		addMorph(geometry, 500, 1000, STARTX - Math.random() * 500, 350, 40)

	loader.load "js/models/stork.js", (geometry) ->
		morphColorsToFaceColors geometry
		addMorph(geometry, 350, 1000, STARTX - Math.random() * 500, 350, 340)
	
	loader.load "js/models/buildings.js", (geometry, materials) ->
		# geometry.scale.set(5,5,5)
		for k in [0..4]
			addStatic(geometry, materials, -STARTX + 600*k, -100, -1500 + Math.ceil(Math.random()*3000))
		

	renderer.initWebGLObjects scene

render = ->
	delta = clock.getDelta()

	setRiverPosition(delta)

	soundVal = THREE.Math.clamp soundVal + delta * soundDir, 0, 1
	if speed != oldSpeed
		soundtrack.playbackRate = 0.75 + (speed-1)/18.0
		oldSpeed = speed

	if (soundVal != oldSoundVal) and soundtrack
		soundtrack.volume = soundVal
		oldSoundVal = soundVal


	if terrain.visible
		controls.update()
		time = Date.now() * 0.001
		fLow = 0.1 #0.1
		fHigh = 0.8 #0.8

		lightVal = THREE.Math.clamp lightVal + 0.5 * delta * lightDir, fLow, fHigh
		valNorm = (lightVal - fLow) / (fHigh - fLow)
		#sat = THREE.Math.mapLinear valNorm, 0, 1, 0.95, 0.25
		scene.fog.color.setHSL 0.1, 0.5, lightVal
		renderer.setClearColor scene.fog.color, 1
		directionalLight.intensity = THREE.Math.mapLinear valNorm, 0, 1, 0.1, 1.15
		pointLight.intensity = THREE.Math.mapLinear valNorm, 0, 1, 0.9, 1.5

		uniformsTerrain['uNormalScale'].value = THREE.Math.mapLinear valNorm, 0, 1, 0.6, 3.5
		
		if updateNoise
			animDelta = THREE.Math.clamp(animDelta + 0.00075 * animDeltaDir, 0, 0.05)
			uniformsNoise["time"].value += delta * animDelta
			uniformsNoise["offset"].value.x += delta * speed * 0.05
			uniformsTerrain["uOffset"].value.x = 4 * uniformsNoise["offset"].value.x
			quadTarget.material = mlib["heightmap"]
			renderer.render sceneRenderTarget, cameraOrtho, heightMap, true
			quadTarget.material = mlib["normal"]
			renderer.render sceneRenderTarget, cameraOrtho, normalMap, true


		for stat in statics
			# stat.updateAnimation 1000 * delta
			stat.position.x -= 180 * delta * speed
			if stat.position.x < -500 && !stat.checked
				checkhit(stat.position.z) if started
				stat.checked = yes
			if stat.position.x <= STARTX
				stat.checked = no 
				stat.position.x = stat.start
				stat.position.z = -1500 + Math.ceil(Math.random()*3000)
				stat.rotation.y = (Math.PI/2) - (stat.position.z / 1500.0)

		for morph in morphs
			morph.updateAnimation 1000 * delta
			morph.position.x += morph.speed * delta
			if morph.position.x > 2000 
				morph.position.x = -1500 - Math.random() * 500

			
		composer.render 0.1

animate = ->
	requestAnimationFrame animate
	render()

init()
animate()

document.getElementById("start").onclick = play