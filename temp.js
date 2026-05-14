
        let projectData = null;
        let isPlaying = false;
        let currentTime = 0;
        let maxTime = 0;
        let animationFrame;
        let lastTimestamp;

        let selectedCaptionId = null;

        // Dragging state
        let isDraggingCaption = false;
        let isRotatingCaption = false;
        let dragStartX = 0;
        let dragStartY = 0;
        let initialValX = 0;
        let initialValY = 0;
        
        let isDraggingTimeline = false;
        let draggingTimelineType = null; // 'left', 'right', or 'body'
        let draggingMarkerId = null;

        const playBtn = document.getElementById('playBtn');
        const playIcon = document.getElementById('playIcon');
        const pauseIcon = document.getElementById('pauseIcon');
        const timeDisplay = document.getElementById('timeDisplay');
        const timeSlider = document.getElementById('timeSlider');
        const sliderWrapper = document.getElementById('sliderWrapper');
        
        const captionsContainer = document.getElementById('captionsContainer');
        const markersContainer = document.getElementById('markersContainer');
        const captionList = document.getElementById('captionList');
        const videoBox = document.getElementById('videoBox');
        
        const emptyInspector = document.getElementById('emptyInspector');
        const inspectorContent = document.getElementById('inspectorContent');

        const DEFAULT_GRADIENT = { type: 'gradient', colors: ['#D4AF37', '#AA771C'] };
        const DEFAULT_SHADOW = { offset_x: 0, offset_y: 5, blur: 15, color: 'rgba(0,0,0,0.9)' };
        const DEFAULT_GLOW = { color: 'rgba(212,175,55,0.5)' };

        function parseColor(colorObj) {
            if (typeof colorObj === 'string') return colorObj;
            if (colorObj && colorObj.type === 'gradient' && colorObj.colors) {
                return `-webkit-linear-gradient(top, ${colorObj.colors.join(', ')})`;
            }
            return '#FFFFFF';
        }

        async function init() {
            try {
                document.body.addEventListener('touchmove', function(e) { 
                    if(e.target.closest('.inspector-panel') === null && e.target.closest('.timeline-panel') === null) { e.preventDefault(); }
                }, { passive: false });

                const response = await fetch('output_captions.json');
                if (!response.ok) throw new Error("HTTP " + response.status);
                projectData = await response.json();
                
                calcMaxTime();
                renderCaptionList();
                setupTimeline();
                renderCaptions();
                
                playBtn.disabled = false;
                timeSlider.disabled = false;
                window.addEventListener('resize', renderCaptions);
            } catch (err) {
                alert("Nefunguje lokální server. Spusťte Python http.server.");
            }
        }

        function calcMaxTime() {
            maxTime = 0;
            if(projectData && projectData.captions) {
                projectData.captions.forEach(c => { if (c.end_time > maxTime) maxTime = c.end_time; });
            }
            maxTime = Math.ceil(maxTime + 1); 
            timeSlider.max = maxTime;
        }

        function renderCaptionList() {
            captionList.innerHTML = '';
            if(!projectData) return;
            projectData.captions.forEach(c => {
                const item = document.createElement('div');
                item.className = 'caption-item' + (c.id === selectedCaptionId ? ' active' : '');
                item.textContent = `[${c.start_time.toFixed(1)}s] ${c.text}`;
                item.onclick = () => {
                    selectCaption(c.id);
                    if(currentTime < c.start_time || currentTime > c.end_time) {
                        currentTime = c.start_time;
                        updateUI();
                    }
                };
                captionList.appendChild(item);
            });
        }

        function setupTimeline() {
            markersContainer.innerHTML = '';
            if(!projectData) return;
            projectData.captions.forEach(c => {
                const startPercent = (c.start_time / maxTime) * 100;
                const widthPercent = ((c.end_time - c.start_time) / maxTime) * 100;
                
                const marker = document.createElement('div');
                marker.className = 'marker' + (c.id === selectedCaptionId ? ' selected' : '');
                marker.id = 'marker_' + c.id;
                marker.style.left = startPercent + '%';
                marker.style.width = widthPercent + '%';
                if(c.category === 'Accent') marker.style.backgroundColor = '#FF0055';

                // Handles
                const leftHandle = document.createElement('div');
                leftHandle.className = 'timeline-handle left';
                const rightHandle = document.createElement('div');
                rightHandle.className = 'timeline-handle right';

                function handleTimelineStart(e, type) {
                    isDraggingTimeline = true;
                    draggingTimelineType = type;
                    draggingMarkerId = c.id;
                    if(isPlaying) playBtn.click();
                }

                leftHandle.addEventListener('mousedown', (e) => { e.stopPropagation(); handleTimelineStart(e, 'left'); });
                leftHandle.addEventListener('touchstart', (e) => { e.stopPropagation(); handleTimelineStart(e, 'left'); }, {passive: false});
                
                rightHandle.addEventListener('mousedown', (e) => { e.stopPropagation(); handleTimelineStart(e, 'right'); });
                rightHandle.addEventListener('touchstart', (e) => { e.stopPropagation(); handleTimelineStart(e, 'right'); }, {passive: false});

                // Body drag
                marker.addEventListener('mousedown', (e) => { e.stopPropagation(); handleTimelineStart(e, 'body'); });
                marker.addEventListener('touchstart', (e) => { e.stopPropagation(); handleTimelineStart(e, 'body'); }, {passive: false});

                marker.appendChild(leftHandle);
                marker.appendChild(rightHandle);
                markersContainer.appendChild(marker);
            });
        }
        
        function updateSingleMarkerUI(caption) {
            const marker = document.getElementById('marker_' + caption.id);
            if(marker) {
                const startPercent = (caption.start_time / maxTime) * 100;
                const widthPercent = ((caption.end_time - caption.start_time) / maxTime) * 100;
                marker.style.left = startPercent + '%';
                marker.style.width = widthPercent + '%';
            }
        }

        function updateSingleCaptionTransform(caption) {
            const wrapper = document.getElementById(caption.id);
            if(!wrapper) return;
            const bWidth = videoBox.clientWidth;
            const bHeight = videoBox.clientHeight;
            const scaleX = bWidth / projectData.resolution.width;
            const scaleY = bHeight / projectData.resolution.height;
            const scale = Math.min(scaleX, scaleY);

            const t = caption.transform_3d || {};
            const pos = t.position || {};
            const rot = t.rotation || {};

            const tx = ((pos.x || 0) * scale) - (bWidth / 2);
            const ty = ((pos.y || 0) * scale) - (bHeight / 2);
            const tz = pos.z || 0;
            const rx = rot.x || 0;
            const ry = rot.y || 0;
            const rz = rot.z || 0;
            wrapper.style.transform = `translate(-50%, -50%) translate3d(${tx}px, ${ty}px, ${tz}px) rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg)`;
        }

        function renderCaptions() {
            captionsContainer.innerHTML = '';
            if(!projectData) return;
            const bWidth = videoBox.clientWidth;
            const bHeight = videoBox.clientHeight;
            const scaleX = bWidth / projectData.resolution.width;
            const scaleY = bHeight / projectData.resolution.height;
            const scale = Math.min(scaleX, scaleY);

            projectData.captions.forEach(c => {
                const wrapper = document.createElement('div');
                wrapper.className = 'caption-wrapper' + (selectedCaptionId === c.id ? ' selected' : '');
                wrapper.id = c.id;

                const textEl = document.createElement('div');
                textEl.className = 'caption';
                textEl.textContent = c.text;
                textEl.style.fontFamily = c.style.font_family || 'Inter';
                textEl.style.fontWeight = c.style.font_weight || '900';
                
                const styleObj = c.style || {};
                textEl.style.fontSize = ((styleObj.font_size || 100) * scale) + 'px';
                
                if (typeof styleObj.color === 'object') {
                    textEl.style.background = parseColor(styleObj.color);
                    textEl.style.webkitBackgroundClip = 'text';
                    textEl.style.webkitTextFillColor = 'transparent';
                } else {
                    textEl.style.color = styleObj.color || '#FFF';
                }

                let filterStr = '';
                if (styleObj.shadow) filterStr += `drop-shadow(${styleObj.shadow.offset_x}px ${styleObj.shadow.offset_y}px ${styleObj.shadow.blur}px ${styleObj.shadow.color}) `;
                if (styleObj.glow) filterStr += `drop-shadow(0px 0px 20px ${styleObj.glow.color})`;
                textEl.style.filter = filterStr;

                // Drag handling for position
                function handleDragStart(e) {
                    selectCaption(c.id);
                    isDraggingCaption = true;
                    dragStartX = e.touches ? e.touches[0].clientX : e.clientX;
                    dragStartY = e.touches ? e.touches[0].clientY : e.clientY;
                    
                    const t = c.transform_3d || {};
                    const pos = t.position || {};
                    initialValX = pos.x || 0;
                    initialValY = pos.y || 0;
                    if(isPlaying) playBtn.click();
                }
                textEl.addEventListener('mousedown', handleDragStart);
                textEl.addEventListener('touchstart', (e) => { e.stopPropagation(); handleDragStart(e); }, {passive: false});

                // Rotate handle
                const rotateHandle = document.createElement('div');
                rotateHandle.className = 'rotate-handle';
                function handleRotateStart(e) {
                    e.stopPropagation();
                    selectCaption(c.id);
                    isRotatingCaption = true;
                    dragStartX = e.touches ? e.touches[0].clientX : e.clientX;
                    dragStartY = e.touches ? e.touches[0].clientY : e.clientY;
                    
                    const t = c.transform_3d || {};
                    const rot = t.rotation || {};
                    initialValX = rot.z || 0; // Horiz drag = Z rot
                    initialValY = rot.x || 0; // Vert drag = X rot
                    if(isPlaying) playBtn.click();
                }
                rotateHandle.addEventListener('mousedown', handleRotateStart);
                rotateHandle.addEventListener('touchstart', (e) => { handleRotateStart(e); }, {passive: false});

                wrapper.appendChild(textEl);
                wrapper.appendChild(rotateHandle);
                captionsContainer.appendChild(wrapper);
                
                // Set initial transform
                updateSingleCaptionTransform(c);
            });
            updateCaptionVisibility();
        }

        function updateCaptionVisibility() {
            if (!projectData) return;
            projectData.captions.forEach(c => {
                const el = document.getElementById(c.id);
                if (el) {
                    if (currentTime >= c.start_time && currentTime <= c.end_time || c.id === selectedCaptionId) {
                        el.style.opacity = 1; el.style.pointerEvents = 'auto';
                    } else {
                        el.style.opacity = 0; el.style.pointerEvents = 'none';
                    }
                }
            });
        }

        function updateUI() {
            timeDisplay.textContent = currentTime.toFixed(1) + 's';
            timeSlider.value = currentTime;
            updateCaptionVisibility();
        }

        function loop(timestamp) {
            if (!lastTimestamp) lastTimestamp = timestamp;
            const delta = (timestamp - lastTimestamp) / 1000;
            lastTimestamp = timestamp;

            if (isPlaying) {
                currentTime += delta;
                if (currentTime > maxTime) currentTime = 0;
                updateUI();
            }
            animationFrame = requestAnimationFrame(loop);
        }

        // --- GLOBAL DRAG EVENTS (Mouse & Touch) ---
        function handleGlobalMove(e) {
            const clientX = e.touches ? e.touches[0].clientX : e.clientX;
            const clientY = e.touches ? e.touches[0].clientY : e.clientY;

            // 1. Position Drag
            if (isDraggingCaption && selectedCaptionId) {
                if(e.cancelable) e.preventDefault(); 
                const scale = Math.max(projectData.resolution.width / videoBox.clientWidth, projectData.resolution.height / videoBox.clientHeight); 
                const dx = (clientX - dragStartX) * scale;
                const dy = (clientY - dragStartY) * scale;

                const caption = projectData.captions.find(c => c.id === selectedCaptionId);
                if(!caption.transform_3d) caption.transform_3d = {};
                if(!caption.transform_3d.position) caption.transform_3d.position = {};
                
                caption.transform_3d.position.x = initialValX + dx;
                caption.transform_3d.position.y = initialValY + dy;
                
                updateSingleCaptionTransform(caption);
                populateInspector(caption);
            }
            // 2. Rotation Drag
            else if (isRotatingCaption && selectedCaptionId) {
                if(e.cancelable) e.preventDefault();
                const dx = (clientX - dragStartX) * 0.5; // Sensitivity
                const dy = (clientY - dragStartY) * 0.5;

                const caption = projectData.captions.find(c => c.id === selectedCaptionId);
                if(!caption.transform_3d) caption.transform_3d = {};
                if(!caption.transform_3d.rotation) caption.transform_3d.rotation = {};
                
                caption.transform_3d.rotation.z = initialValX + dx;
                caption.transform_3d.rotation.x = initialValY - dy; // Invert Y
                
                updateSingleCaptionTransform(caption);
                populateInspector(caption);
            }
            // 3. Timeline Drag
            else if (isDraggingTimeline && draggingMarkerId) {
                if(e.cancelable) e.preventDefault();
                const rect = sliderWrapper.getBoundingClientRect();
                let percent = (clientX - rect.left) / rect.width;
                percent = Math.max(0, Math.min(1, percent));
                const newTime = percent * maxTime;

                const caption = projectData.captions.find(c => c.id === draggingMarkerId);
                
                if (draggingTimelineType === 'left') {
                    caption.start_time = Math.min(newTime, caption.end_time - 0.1);
                    currentTime = caption.start_time;
                } else if (draggingTimelineType === 'right') {
                    caption.end_time = Math.max(newTime, caption.start_time + 0.1);
                    currentTime = caption.end_time;
                } else if (draggingTimelineType === 'body') {
                    const duration = caption.end_time - caption.start_time;
                    caption.start_time = Math.max(0, Math.min(newTime, maxTime - duration));
                    caption.end_time = caption.start_time + duration;
                    currentTime = caption.start_time;
                }
                
                updateSingleMarkerUI(caption);
                updateUI();
                if(draggingMarkerId === selectedCaptionId) populateInspector(caption);
            }
        }
        
        function handleGlobalEnd() { 
            if(isDraggingTimeline) {
                renderCaptionList(); // Only update list once drag is done
            }
            isDraggingCaption = false; 
            isRotatingCaption = false;
            isDraggingTimeline = false;
            draggingMarkerId = null;
        }

        document.addEventListener('mousemove', handleGlobalMove);
        document.addEventListener('touchmove', handleGlobalMove, {passive: false});
        document.addEventListener('mouseup', handleGlobalEnd);
        document.addEventListener('touchend', handleGlobalEnd);

        // --- Inspector & List Logic ---
        function selectCaption(id) {
            selectedCaptionId = id;
            const caption = projectData.captions.find(c => c.id === id);
            if(!caption) return;
            
            // Only update DOM classes instead of recreating everything
            document.querySelectorAll('.caption-item').forEach(el => el.classList.remove('active'));
            const listItems = document.querySelectorAll('.caption-item');
            const index = projectData.captions.findIndex(c => c.id === id);
            if(index !== -1 && listItems[index]) listItems[index].classList.add('active');

            document.querySelectorAll('.marker').forEach(el => el.classList.remove('selected'));
            const marker = document.getElementById('marker_' + id);
            if(marker) marker.classList.add('selected');

            document.querySelectorAll('.caption-wrapper').forEach(el => el.classList.remove('selected'));
            const wrapper = document.getElementById(id);
            if(wrapper) wrapper.classList.add('selected');

            populateInspector(caption);
            emptyInspector.style.display = 'none';
            inspectorContent.style.display = 'block';
            updateCaptionVisibility();
        }

        function populateInspector(c) {
            document.getElementById('propText').value = c.text;
            
            const styleObj = c.style || {};
            document.getElementById('propSize').value = styleObj.font_size || 100;
            
            const t = c.transform_3d || {};
            const pos = t.position || {};
            const rot = t.rotation || {};
            
            document.getElementById('propX').value = Math.round(pos.x || 0);
            document.getElementById('propY').value = Math.round(pos.y || 0);
            document.getElementById('propZ').value = Math.round(pos.z || 0);
            document.getElementById('propRotX').value = Math.round(rot.x || 0);
            document.getElementById('propRotY').value = Math.round(rot.y || 0);
            document.getElementById('propRotZ').value = Math.round(rot.z || 0);

            document.getElementById('propGradient').checked = (typeof styleObj.color === 'object');
            document.getElementById('propShadow').checked = !!styleObj.shadow;
            document.getElementById('propGlow').checked = !!styleObj.glow;
        }

        function updateProp(propName, value) {
            if(!selectedCaptionId) return;
            const c = projectData.captions.find(c => c.id === selectedCaptionId);
            if(!c) return;

            if(!c.style) c.style = {};
            if(!c.transform_3d) c.transform_3d = {};
            if(!c.transform_3d.position) c.transform_3d.position = {};
            if(!c.transform_3d.rotation) c.transform_3d.rotation = {};
            
            if(propName === 'text') { c.text = value; renderCaptionList(); }
            if(propName === 'font_size') c.style.font_size = parseInt(value) || 100;
            if(propName === 'pos_x') c.transform_3d.position.x = parseFloat(value) || 0;
            if(propName === 'pos_y') c.transform_3d.position.y = parseFloat(value) || 0;
            if(propName === 'pos_z') c.transform_3d.position.z = parseFloat(value) || 0;
            if(propName === 'rot_x') c.transform_3d.rotation.x = parseFloat(value) || 0;
            if(propName === 'rot_y') c.transform_3d.rotation.y = parseFloat(value) || 0;
            if(propName === 'rot_z') c.transform_3d.rotation.z = parseFloat(value) || 0;

            renderCaptions(); // Re-render to apply new text/size/rotation
            selectCaption(selectedCaptionId); // Reselect to keep classes
        }

        function updateStyleToggle(type, isChecked) {
            if(!selectedCaptionId) return;
            const c = projectData.captions.find(c => c.id === selectedCaptionId);
            if(!c) return;
            if(!c.style) c.style = {};
            
            if(type === 'gradient') {
                if(isChecked) c.style.color = DEFAULT_GRADIENT;
                else c.style.color = '#FFFFFF';
            }
            if(type === 'shadow') {
                if(isChecked) c.style.shadow = DEFAULT_SHADOW;
                else delete c.style.shadow;
            }
            if(type === 'glow') {
                if(isChecked) c.style.glow = DEFAULT_GLOW;
                else delete c.style.glow;
            }
            renderCaptions();
            selectCaption(selectedCaptionId);
        }

        // Click on background to deselect
        function handleWorkspaceClick(e) {
            if(e.target.id === 'workspace' || e.target.id === 'videoBox' || e.target.classList.contains('mock-video-bg')) {
                selectedCaptionId = null;
                document.querySelectorAll('.caption-item').forEach(el => el.classList.remove('active'));
                document.querySelectorAll('.marker').forEach(el => el.classList.remove('selected'));
                document.querySelectorAll('.caption-wrapper').forEach(el => el.classList.remove('selected'));
                emptyInspector.style.display = 'block';
                inspectorContent.style.display = 'none';
                updateCaptionVisibility();
            }
        }
        document.getElementById('workspace').addEventListener('mousedown', handleWorkspaceClick);
        document.getElementById('workspace').addEventListener('touchstart', handleWorkspaceClick);

        function exportJson() {
            if(!projectData) return;
            const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(projectData, null, 2));
            const downloadAnchorNode = document.createElement('a');
            downloadAnchorNode.setAttribute("href",     dataStr);
            downloadAnchorNode.setAttribute("download", "output_captions.json");
            document.body.appendChild(downloadAnchorNode); 
            downloadAnchorNode.click();
            downloadAnchorNode.remove();
        }

        init();
    