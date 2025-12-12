// ==UserScript==
// @name         Amazon: URL Cleaner
// @description  Replace the URL with the shortest possible clean URL for Amazon items
// @include      *://*.amazon.tld/dp/*
// @include      *://*.amazon.tld/*/dp/*
// @include      *://*.amazon.tld/gp/product/*
// @include      *://*.amazon.tld/*/ASIN/*
// @grant        none
// @icon         https://www.amazon.com/favicon.ico
// @run-at       document-start
// ==/UserScript==
/* jshint esversion: 6 */

(function () {
    'use strict';

    function getProductId() {
        const regex = /(?:\/.+\/)?(?:dp|gp\/product|ASIN)\/([^\/?]+)/;
        const match = document.location.href.match(regex);
        return match ? match[1] : null;
    }

    // Early exit if the URL doesn't match any expected patterns
    if (!/(?:dp|gp\/product|ASIN)\//.test(document.location.href)) {
        return;
    }

    const productId = getProductId();

    if (productId && /^[A-Z0-9]+$/.test(productId)) {
        const cleanUrl = `https://${window.location.hostname}/dp/${productId}`;
        history.replaceState({}, document.title, cleanUrl);
    } else {
        console.error('Invalid product ID or URL:', productId, document.location.href);
    }
})();
