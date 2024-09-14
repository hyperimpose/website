import shutil
from pathlib import Path

import html5lib
from jinja2 import Environment, PackageLoader, select_autoescape


env = Environment(
    loader=PackageLoader("__main__"),
    autoescape=select_autoescape()
)

GENERATOR_ROOT = Path(__file__).absolute().parent
CONTENT = Path(GENERATOR_ROOT / "content")
STATIC = Path(GENERATOR_ROOT / "static")
OUTPUT = Path(GENERATOR_ROOT / "../docs")


def get_content(path):
    with open(path, "r") as fp:
        return fp.read()


def index():
    template = env.get_template("index.jinja")
    with open(OUTPUT / "index.html", "w") as fp:
        fp.write(template.render())


def blog():
    blog = CONTENT / "blog"

    articles = [x for x in blog.iterdir() if x.is_dir()]

    template = env.get_template("blog/article.jinja")

    article_info = []
    for article in articles:
        document = html5lib.parse(
            get_content(article / "index.html"),
            namespaceHTMLElements=False)

        h2 = document.find(".//h2")
        if h2 is not None:
            h2 = h2.text
        else:
            h2 = "Untitled"

        date = "0000-00-00"
        d = article.name.split("_")
        if len(d) == 2:
            date = d[0]

        article_info.append({
            "link": f"/blog/{article.name}",
            "title": h2,
            "date": date
        })

        shutil.copytree(article, OUTPUT / "blog" / article.name)
        with open(OUTPUT / "blog" / article.name / "index.html", "w") as fp:
            fp.write(template.render(
                title=h2,
                breadcrumbs=[
                    ("/", "hyperimpose.org"), ("/blog", "blog"), ("", h2)
                ],
                content=get_content(article / "index.html")))

    template = env.get_template("blog/blog.jinja")

    index = OUTPUT / "blog" / "index.html"
    index.parent.mkdir(exist_ok=True, parents=True)

    with open(index, "w") as fp:
        fp.write(template.render(
            breadcrumbs=[("/", "hyperimpose.org"), ("", "blog")],
            articles=article_info))


def drastikbot_help():
    base = CONTENT / "drastikbot" / "help"
    extensions = [x for x in base.iterdir() if x.is_dir()]

    template = env.get_template("blog/article.jinja")

    for e in extensions:
        shutil.copytree(e, OUTPUT / "drastikbot" / "help" / e.name)
        with open(OUTPUT / "drastikbot" / "help" / e.name / "index.html", "w") as fp:
            fp.write(template.render(
                title=e.name,
                content=get_content(e / "index.html")))


if __name__ == "__main__":
    for file in OUTPUT.glob("*"):
        if file.is_dir():
            shutil.rmtree(file)
        else:
            file.unlink()

    # /index.html
    index()

    # /blog/index.html
    # And every article
    blog()

    # /drastikbot/help/* every help page
    drastikbot_help()

    # static files
    shutil.copytree(STATIC, f"{OUTPUT}/static")

    # CNAME for Github Pages
    shutil.copyfile(CONTENT / "CNAME", OUTPUT / "CNAME")
