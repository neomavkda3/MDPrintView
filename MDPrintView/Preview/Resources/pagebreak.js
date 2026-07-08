// Page-break interaction: delegated clicks on #content (delegation survives
// the innerHTML swaps the preview does on every render).
//
// .break-gap click          -> add a break after that boundary
// .page-break-remove click  -> remove the break at that boundary
(function () {
    document.addEventListener('click', function (e) {
        if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.pageBreak) { return; }
        var removeBtn = e.target.closest('.page-break-remove');
        if (removeBtn) {
            window.webkit.messageHandlers.pageBreak.postMessage({
                action: 'remove',
                after: parseInt(removeBtn.getAttribute('data-after'), 10)
            });
            return;
        }
        var gap = e.target.closest('.break-gap');
        if (gap) {
            window.webkit.messageHandlers.pageBreak.postMessage({
                action: 'add',
                after: parseInt(gap.getAttribute('data-after'), 10)
            });
        }
    });
})();
