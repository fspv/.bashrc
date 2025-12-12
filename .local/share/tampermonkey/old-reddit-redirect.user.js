// ==UserScript==
// @name         Old Reddit Redirect
// @version      1.0.0
// @description  Automatically redirects you to the old reddit
// @match        https://www.reddit.com/*
// @match        https://reddit.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function () {
    'use strict';
    top.location.hostname = "old.reddit.com";
})();
