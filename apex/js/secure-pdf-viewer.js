/**
 * Secure PDF Viewer for Oracle APEX
 *
 * This viewer uses PDF.js to render PDFs with download restrictions:
 * - No download button
 * - No print functionality
 * - Right-click disabled
 * - Keyboard shortcuts for save/print blocked
 * - Content copy disabled
 *
 * Usage:
 *   SecurePDFViewer.init({
 *     containerId: 'pdf-viewer-container',
 *     pdfUrl: '&PDF_URL.',
 *     scale: 1.0
 *   });
 */

var SecurePDFViewer = (function() {
    'use strict';

    // Configuration
    var config = {
        containerId: 'pdf-viewer-container',
        pdfUrl: null,
        scale: 1.0,
        maxScale: 3.0,
        minScale: 0.5,
        workerSrc: 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js'
    };

    // State
    var state = {
        pdfDoc: null,
        currentPage: 1,
        totalPages: 0,
        rendering: false,
        pendingPage: null
    };

    // DOM Elements
    var elements = {
        container: null,
        canvas: null,
        ctx: null,
        pageNum: null,
        pageCount: null,
        prevBtn: null,
        nextBtn: null,
        zoomInBtn: null,
        zoomOutBtn: null,
        loadingOverlay: null
    };

    /**
     * Initialize the PDF viewer
     */
    function init(options) {
        // Merge options
        if (options) {
            for (var key in options) {
                if (options.hasOwnProperty(key)) {
                    config[key] = options[key];
                }
            }
        }

        // Set PDF.js worker
        pdfjsLib.GlobalWorkerOptions.workerSrc = config.workerSrc;

        // Setup container and controls
        setupViewer();

        // Apply security measures
        applySecurityMeasures();

        // Load PDF if URL provided
        if (config.pdfUrl) {
            loadPDF(config.pdfUrl);
        }
    }

    /**
     * Setup viewer HTML structure
     */
    function setupViewer() {
        elements.container = document.getElementById(config.containerId);
        if (!elements.container) {
            console.error('PDF viewer container not found: ' + config.containerId);
            return;
        }

        // Create viewer HTML
        elements.container.innerHTML = `
            <div class="secure-pdf-wrapper">
                <div class="pdf-toolbar">
                    <div class="toolbar-group">
                        <button type="button" id="pdf-prev" class="pdf-btn" title="Previous Page">
                            <span class="fa fa-chevron-left"></span>
                        </button>
                        <span class="page-info">
                            <span id="pdf-page-num">1</span> / <span id="pdf-page-count">-</span>
                        </span>
                        <button type="button" id="pdf-next" class="pdf-btn" title="Next Page">
                            <span class="fa fa-chevron-right"></span>
                        </button>
                    </div>
                    <div class="toolbar-group">
                        <button type="button" id="pdf-zoom-out" class="pdf-btn" title="Zoom Out">
                            <span class="fa fa-search-minus"></span>
                        </button>
                        <span id="pdf-zoom-level" class="zoom-level">100%</span>
                        <button type="button" id="pdf-zoom-in" class="pdf-btn" title="Zoom In">
                            <span class="fa fa-search-plus"></span>
                        </button>
                    </div>
                    <div class="toolbar-group">
                        <button type="button" id="pdf-fullscreen" class="pdf-btn" title="Full Screen">
                            <span class="fa fa-expand"></span>
                        </button>
                    </div>
                </div>
                <div class="pdf-canvas-container">
                    <div class="pdf-loading-overlay" id="pdf-loading">
                        <div class="loading-spinner">
                            <span class="fa fa-spinner fa-spin fa-3x"></span>
                            <p>Loading document...</p>
                        </div>
                    </div>
                    <canvas id="pdf-canvas"></canvas>
                </div>
            </div>
        `;

        // Get DOM references
        elements.canvas = document.getElementById('pdf-canvas');
        elements.ctx = elements.canvas.getContext('2d');
        elements.pageNum = document.getElementById('pdf-page-num');
        elements.pageCount = document.getElementById('pdf-page-count');
        elements.prevBtn = document.getElementById('pdf-prev');
        elements.nextBtn = document.getElementById('pdf-next');
        elements.zoomInBtn = document.getElementById('pdf-zoom-in');
        elements.zoomOutBtn = document.getElementById('pdf-zoom-out');
        elements.loadingOverlay = document.getElementById('pdf-loading');

        // Attach event handlers
        elements.prevBtn.addEventListener('click', prevPage);
        elements.nextBtn.addEventListener('click', nextPage);
        elements.zoomInBtn.addEventListener('click', zoomIn);
        elements.zoomOutBtn.addEventListener('click', zoomOut);
        document.getElementById('pdf-fullscreen').addEventListener('click', toggleFullscreen);

        // Add keyboard navigation
        document.addEventListener('keydown', handleKeyboard);
    }

    /**
     * Apply security measures to prevent download
     */
    function applySecurityMeasures() {
        var wrapper = elements.container.querySelector('.secure-pdf-wrapper');
        if (!wrapper) return;

        // Disable right-click context menu
        wrapper.addEventListener('contextmenu', function(e) {
            e.preventDefault();
            showSecurityMessage('Right-click is disabled for this document.');
            return false;
        });

        // Disable text selection on the canvas
        elements.canvas.style.userSelect = 'none';
        elements.canvas.style.webkitUserSelect = 'none';
        elements.canvas.style.msUserSelect = 'none';

        // Block keyboard shortcuts for save/print
        document.addEventListener('keydown', function(e) {
            // Block Ctrl+S (Save), Ctrl+P (Print), Ctrl+Shift+S (Save As)
            if ((e.ctrlKey || e.metaKey) &&
                (e.key === 's' || e.key === 'S' || e.key === 'p' || e.key === 'P')) {
                e.preventDefault();
                showSecurityMessage('Download and print are disabled for this document.');
                return false;
            }
        });

        // Prevent drag and drop of canvas content
        elements.canvas.addEventListener('dragstart', function(e) {
            e.preventDefault();
            return false;
        });

        // Add watermark overlay (optional)
        addWatermarkOverlay(wrapper);
    }

    /**
     * Add a semi-transparent watermark overlay
     */
    function addWatermarkOverlay(wrapper) {
        var watermark = document.createElement('div');
        watermark.className = 'pdf-watermark';
        watermark.innerHTML = '<span>VIEW ONLY</span>';
        wrapper.querySelector('.pdf-canvas-container').appendChild(watermark);
    }

    /**
     * Show security message to user
     */
    function showSecurityMessage(message) {
        apex.message.showPageSuccess(message);
        setTimeout(function() {
            apex.message.hidePageSuccess();
        }, 3000);
    }

    /**
     * Load PDF from URL
     */
    function loadPDF(url) {
        showLoading(true);

        // Load PDF with credentials for APEX
        pdfjsLib.getDocument({
            url: url,
            withCredentials: true
        }).promise.then(function(pdf) {
            state.pdfDoc = pdf;
            state.totalPages = pdf.numPages;
            elements.pageCount.textContent = state.totalPages;

            // Render first page
            renderPage(1);
        }).catch(function(error) {
            console.error('Error loading PDF:', error);
            showError('Failed to load document. Please try again.');
            showLoading(false);
        });
    }

    /**
     * Render a specific page
     */
    function renderPage(pageNumber) {
        state.rendering = true;

        state.pdfDoc.getPage(pageNumber).then(function(page) {
            var viewport = page.getViewport({ scale: config.scale });

            // Set canvas dimensions
            elements.canvas.height = viewport.height;
            elements.canvas.width = viewport.width;

            // Render context
            var renderContext = {
                canvasContext: elements.ctx,
                viewport: viewport
            };

            page.render(renderContext).promise.then(function() {
                state.rendering = false;
                state.currentPage = pageNumber;
                elements.pageNum.textContent = pageNumber;

                // Update button states
                updateButtonStates();
                showLoading(false);

                // Render pending page if any
                if (state.pendingPage !== null) {
                    renderPage(state.pendingPage);
                    state.pendingPage = null;
                }
            });
        });
    }

    /**
     * Queue page render
     */
    function queueRenderPage(pageNumber) {
        if (state.rendering) {
            state.pendingPage = pageNumber;
        } else {
            renderPage(pageNumber);
        }
    }

    /**
     * Go to previous page
     */
    function prevPage() {
        if (state.currentPage <= 1) return;
        queueRenderPage(state.currentPage - 1);
    }

    /**
     * Go to next page
     */
    function nextPage() {
        if (state.currentPage >= state.totalPages) return;
        queueRenderPage(state.currentPage + 1);
    }

    /**
     * Zoom in
     */
    function zoomIn() {
        if (config.scale >= config.maxScale) return;
        config.scale += 0.25;
        updateZoomLevel();
        queueRenderPage(state.currentPage);
    }

    /**
     * Zoom out
     */
    function zoomOut() {
        if (config.scale <= config.minScale) return;
        config.scale -= 0.25;
        updateZoomLevel();
        queueRenderPage(state.currentPage);
    }

    /**
     * Update zoom level display
     */
    function updateZoomLevel() {
        document.getElementById('pdf-zoom-level').textContent =
            Math.round(config.scale * 100) + '%';
    }

    /**
     * Toggle fullscreen mode
     */
    function toggleFullscreen() {
        var wrapper = elements.container.querySelector('.secure-pdf-wrapper');
        if (!document.fullscreenElement) {
            wrapper.requestFullscreen().catch(function(err) {
                console.log('Fullscreen error:', err);
            });
        } else {
            document.exitFullscreen();
        }
    }

    /**
     * Handle keyboard navigation
     */
    function handleKeyboard(e) {
        if (document.activeElement.tagName === 'INPUT') return;

        switch(e.key) {
            case 'ArrowLeft':
            case 'PageUp':
                prevPage();
                break;
            case 'ArrowRight':
            case 'PageDown':
            case ' ':
                nextPage();
                e.preventDefault();
                break;
            case '+':
            case '=':
                if (e.ctrlKey) {
                    e.preventDefault();
                    zoomIn();
                }
                break;
            case '-':
                if (e.ctrlKey) {
                    e.preventDefault();
                    zoomOut();
                }
                break;
        }
    }

    /**
     * Update button states based on current page
     */
    function updateButtonStates() {
        elements.prevBtn.disabled = (state.currentPage <= 1);
        elements.nextBtn.disabled = (state.currentPage >= state.totalPages);
    }

    /**
     * Show/hide loading overlay
     */
    function showLoading(show) {
        elements.loadingOverlay.style.display = show ? 'flex' : 'none';
    }

    /**
     * Show error message
     */
    function showError(message) {
        elements.container.innerHTML = `
            <div class="pdf-error">
                <span class="fa fa-exclamation-triangle fa-3x"></span>
                <p>${message}</p>
            </div>
        `;
    }

    /**
     * Go to specific page
     */
    function goToPage(pageNumber) {
        if (pageNumber < 1 || pageNumber > state.totalPages) return;
        queueRenderPage(pageNumber);
    }

    /**
     * Get current page number
     */
    function getCurrentPage() {
        return state.currentPage;
    }

    /**
     * Get total pages
     */
    function getTotalPages() {
        return state.totalPages;
    }

    // Public API
    return {
        init: init,
        loadPDF: loadPDF,
        goToPage: goToPage,
        prevPage: prevPage,
        nextPage: nextPage,
        zoomIn: zoomIn,
        zoomOut: zoomOut,
        getCurrentPage: getCurrentPage,
        getTotalPages: getTotalPages
    };

})();
