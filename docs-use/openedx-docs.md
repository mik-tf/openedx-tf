# Open edX Docs

## Introduction

We provide notes to manage the Open edX platform.

## Features

- Create admin account
tutor local exec lms ./manage.py lms createsuperuser
- Make existing user admin
tutor local exec lms ./manage.py lms manage_user your_email@example.com --staff --superuser
