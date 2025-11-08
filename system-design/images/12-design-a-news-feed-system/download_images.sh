#!/bin/bash
base_url="https://bytebytego.com/images/courses/system-design-interview/design-a-news-feed-system"

# Download all images
curl -L -o "figure-11-1-UFCYN5DT.svg" "${base_url}/figure-11-1-UFCYN5DT.svg"
curl -L -o "figure-11-2-DHBRUF3G.png" "${base_url}/figure-11-2-DHBRUF3G.png"
curl -L -o "figure-11-3-DJSVC462.png" "${base_url}/figure-11-3-DJSVC462.png"
curl -L -o "figure-11-4-XQVJN6AJ.png" "${base_url}/figure-11-4-XQVJN6AJ.png"
curl -L -o "figure-11-5-RFHWCGXD.svg" "${base_url}/figure-11-5-RFHWCGXD.svg"
curl -L -o "figure-11-7-VBGEYZ3E.png" "${base_url}/figure-11-7-VBGEYZ3E.png"
curl -L -o "figure-11-8-XPCIBE53.svg" "${base_url}/figure-11-8-XPCIBE53.svg"

echo "Download complete!"
