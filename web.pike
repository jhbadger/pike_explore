#!/usr/bin/env pike

import Protocols.HTTP;

void handle_url(string this_url) {
	write("Fetching '" + this_url + "'...\n");
	Query web_page = get_url(this_url);
	if (web_page == 0) {
		write("Failed.\n");
	} else {
		write(web_page->data());
	}
}

int main(int argc, array(string) argv) {
	handle_url(argv[1]);
}
