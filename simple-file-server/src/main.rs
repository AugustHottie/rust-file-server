use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use infer::get_from_path;
use url_escape::decode;

fn main() {
    server_listener(&Path::new("./public"));
}

fn server_listener(path: &Path) {
    let listener = TcpListener::bind("127.0.0.1:8080").unwrap();

    for stream in listener.incoming() {
        let stream = stream.expect("Failed to accept connection");
        handle_connection(stream, path);
    }
}

fn handle_connection(mut stream: TcpStream, path: &Path) {
    let paths = walk_dir_and_get_paths(path);

    let mut requested_path = path.join(get_requested_path_from_stream(&stream));

    match requested_path.to_str().unwrap() {
        "/" => {
            requested_path = PathBuf::from("/public");
        }
        _ => {
            requested_path = PathBuf::from("./public".to_string() + requested_path.to_str().unwrap());
        }
    }

    println!("Requested path: {}", requested_path.to_str().unwrap());

    // If path is the /, return the paths
    if requested_path.to_str().expect("Failed to convert path to string") == "/public" {
        let response = directory_html_response(paths, "/");
        stream.write(response.as_bytes()).unwrap();
        stream.flush().unwrap();
    }

    // If path is a file, return the file
    else if requested_path.is_file() {
        let file_content = std::fs::read(&requested_path).unwrap();
        let content_type = match get_from_path(&requested_path).unwrap() {
            Some(kind) => kind.mime_type(),
            None => "application/octet-stream",
        };
        let response = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: {}\r\nContent-Length: {}\r\n\r\n",
            content_type,
            file_content.len()
        );
        stream.write(response.as_bytes()).unwrap();
        stream.write(&file_content).unwrap();
        stream.flush().unwrap();
    }

    else if requested_path.is_dir() {
        let response = directory_html_response(walk_dir_and_get_paths(&requested_path), requested_path.to_str().unwrap());
        stream.write(response.as_bytes()).unwrap();
        stream.flush().unwrap();
    }

    // If we cannot find the file, return a 404
    else {
        let response = "HTTP/1.1 404 NOT FOUND\r\nContent-Type: text/html; charset=UTF-8\r\n\r\nFile not found";
        stream.write(response.as_bytes()).unwrap();
        stream.flush().unwrap();
    }
}

fn walk_dir_and_get_paths(path: &Path) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    
    for entry in std::fs::read_dir(path).expect("Failed to read directory") {
        if let Ok(entry) = entry {
            paths.push(entry.path());
        }
    }
    
    // Remove the ./public from the paths and filter out empty ones
    paths.iter()
        .map(|p| PathBuf::from(p.to_str().unwrap().replace("./public", "")))
        .filter(|p| !p.as_os_str().is_empty())
        .collect()
}

fn get_requested_path_from_stream(mut stream: &TcpStream) -> PathBuf {
    let mut request = [0; 1024];

    stream.read(&mut request).unwrap();
    let request_str = String::from_utf8_lossy(&request);
    let request_parts: Vec<&str> = request_str.split(" ").collect();
    let requested_path = request_parts[1];

    let decoded_path = decode(requested_path).to_string();
    PathBuf::from(decoded_path)
}

fn directory_html_response(paths: Vec<PathBuf>, current_dir: &str) -> String {
    println!("{:?}", paths);
    let back_link = if current_dir == "/" {
        String::new()
    } else {
        "<a href=\"..\">..</a><br>\n".to_string()
    };
    let html_content = format!(
        "<h1>{}</h1>\n{}{}",
        current_dir.replacen("/public", "", 1),
        back_link,
        paths.iter()
            .map(|p| format!("<a href=\"{}\">{}</a><br>", p.to_str().unwrap(), p.file_name().unwrap().to_str().unwrap()))
            .collect::<Vec<String>>()
            .join("\n")
    );
    
    format!(
        "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n<html><body>{}</body></html>",
        html_content
    )
}